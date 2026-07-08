#!/usr/bin/env bash
uptime -p | sed 's/up //;s/,//g;s/  / /g'
