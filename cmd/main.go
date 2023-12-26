package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"

	"tailscale.com/client/tailscale"
)

func main() {
	bindAddr := flag.String("listen", ":38388", "Bind address for HTTP proxy")
	proxyTo := flag.String("upstream", "http://localhost:3000", "Upstream address to proxy traffic to")
	flag.Parse()
	ctx := context.Background()
	client := &tailscale.LocalClient{}
	status, err := client.Status(ctx)
	if err != nil {
		log.Fatalf("unable to get tailscale status")
	}
	log.Printf("connected to tailscale local API v%s", status.Version)
	url, err := url.Parse(*proxyTo)
	if err != nil {
		log.Fatalf("unable to parse upstream proxy %s: %s", *proxyTo, err)
	}
	proxy := httputil.NewSingleHostReverseProxy(url)
	orig := proxy.Director
	proxy.Director = func(req *http.Request) {
		var remote string
		if xff := req.Header.Get("X-Forwarded-For"); xff != "" {
			_, remotePort, found := strings.Cut(req.RemoteAddr, ":")
			if !found {
				log.Fatalf("bad remote address?!")
			}
			remote = strings.SplitN(xff, " ", 2)[0]
			remote = strings.TrimPrefix(remote, "::ffff:")
			remote = fmt.Sprintf("%s:%s", remote, remotePort)
		} else {
			remote = req.RemoteAddr
		}
		asaddr,err := net.ResolveTCPAddr("tcp", remote)
		if err != nil {
			log.Fatal(err)
		}
		// Delete these first in case someone tries to insert them?
		req.Header.Del("X-Webauth-Name")
		req.Header.Del("X-Webauth-User")
		req.Header.Del("X-Webauth-Profile-Pic")
		log.Printf("%s %s %s", remote, req.Method, req.URL.Path)
		if whois, err := client.WhoIs(ctx, asaddr.String()); err == nil {
			log.Printf("tailscale user: %s", whois.UserProfile)
			req.Header.Set("X-Webauth-Name", whois.UserProfile.DisplayName)
			req.Header.Set("X-Webauth-User", whois.UserProfile.LoginName)
			req.Header.Set("X-Webauth-Profile-Pic", whois.UserProfile.ProfilePicURL)
		} else {
			log.Printf("unable to get tailscale id for: >%s<", remote)
			log.Print(err)
		}
		orig(req)
	}
	log.Fatal(http.ListenAndServe(*bindAddr, proxy))
}
