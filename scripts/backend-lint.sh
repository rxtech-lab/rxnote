#!/bin/bash
set -e
cd /Users/qiweili/Desktop/rxlab/rx-note/backend
bun run lint 2>&1 | head -100
