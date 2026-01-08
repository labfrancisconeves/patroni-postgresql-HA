#!/bin/bash

curl -sf http://10.20.20.181:8008/master &gt; /dev/null
exit $?
