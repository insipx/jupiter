#!/bin/bash

fly secrets set RATHOLE_CONFIG=(base64 < $1 | tr -d '\n') -a jupiter-gateway
