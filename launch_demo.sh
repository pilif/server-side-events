#!/bin/bash

cd sledgehammer/
./server.js &
cd ..
cd long-polling
FORWARDER_CONFIG=cfg.json bin/event-forwarder.js &
cd ..
cd frontend
./frontend.js &
sleep 1
open http://localhost:3000
read
kill %3 %2 %1
