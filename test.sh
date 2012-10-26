#!/bin/bash
site="hesesn1234"

if [ -d "$homeSites/$site.domain" ]; then
        echo "Sorry, site already exist"
        exit 101;
elif grep -v '^[-0-9a-zA-Z]*$' <<< "$site"; then
        echo "Sitename must be alphanumerical"
        exit 102
elif [ "${#site}" != "10" ]; then
        echo "Sitename must have ten characters"
        exit 103
fi
