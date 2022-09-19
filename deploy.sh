#!/bin/bash
rm -rfv ./public/*
hugo
cd public
git add -A
git commit -m "update"
git push -u git@github.com:stceum/Blog.git master:pages
