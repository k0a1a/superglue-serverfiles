#!/bin/ash

echo -e "Content-type: text/html\n"

echo -e "<!doctype html><html>
<head>
<title>Superglue test</title>
<style>body { font-family: monospace; white-space: pre;}</style>
</head>
<body>
<h2>Superglue test server</h2>

$(uptime)

$(head -n5 /proc/cpuinfo)

$(free)

$(df -h)

$(env)

$(echo $PATH)

$(echo $USER)

</body></html>"

exit 0