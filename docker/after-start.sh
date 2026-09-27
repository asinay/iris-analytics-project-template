#!/bin/bash
# Run after `iris start` by /iris-main (see docker-compose.yml's command: override), replacing
# docker-entrypoint.sh's own after-start step, which crashes under Docker Desktop/WSL2. Uses plain
# ObjectScript only, no embedded Python.
set -e

iris session "$ISC_PACKAGE_INSTANCENAME" -U%SYS <<-'EOSESS' > /dev/null
set prop("Enabled")=1
Do ##class(Security.Services).Modify("%Service_CallIn",.prop)
halt
EOSESS

if [ -n "$IRIS_PASSWORD" ]; then
iris session "$ISC_PACKAGE_INSTANCENAME" -U%SYS <<-EOSESS > /dev/null
check(sc)	if 'sc { do ##class(%SYSTEM.OBJ).DisplayError(sc) do ##class(%SYSTEM.Process).Terminate(, 1) }
set exists = ##class(Security.Users).Exists("$IRIS_USERNAME", .user)
if 'exists { set sc = ##class(Security.Users).Create("$IRIS_USERNAME", "%All", "$IRIS_PASSWORD") }
if exists,\$isobject(user) { set user.PasswordExternal = "$IRIS_PASSWORD", sc = user.%Save() }
do check(sc)
halt
EOSESS
fi
