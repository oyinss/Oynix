#!/bin/sh
# Returns an ISO date roughly 90 days back, for X/Twitter "since:" searches.
date -d "90 days ago" +%Y-%m-%d
