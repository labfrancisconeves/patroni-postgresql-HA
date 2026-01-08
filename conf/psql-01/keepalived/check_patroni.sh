#!/bin/bash

curl -sf http://127.0.0.1:8008/master &gt; /dev/null
exit $?
