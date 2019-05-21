#!/bin/bash

OUTFILE=
INFILE=
URL='http://overpass-api.de/api/interpreter'

while getopts "hi:o:u:" anopt; do
	case "${anopt}" in
		i)
			INFILE=${OPTARG}
			;;
		o)
			OUTFILE=${OPTARG}
			;;
		u)
			URL=${URL}
			;;
		h)
			echo "Usage : $0 [-i infile] [-o outfile] [-u api-url]"; exit 1
			;;
	esac
done
must_delete_INFILE=0
must_delete_OUTFILE=0
if [ "${INFILE}" == "" ]; then
	INFILE=$(mktemp "/tmp/osm.$$.XXXXXXX")
	must_delete_INFILE=1
	echo "$0 : enter below the query in XML format, press CTRL-D when done:"
	QUERY=$(cat > "${INFILE}")
fi
if [ "${OUTFILE}" == "" ]; then
	OUTFILE=$(mktemp "/tmp/osm.$$.XXXXXXX")
	must_delete_OUTFILE=1
fi

if [ ! -s "${INFILE}" ]; then  echo "$0 : empty input, stop."; exit 1; fi

CMD="wget \
--post-file='${INFILE}' \
'${URL}' \
--output-document='${OUTFILE}' \
"
es=0
eval ${CMD}
if [ $? -ne 0 ]; then
	cat "${INFILE}"
	echo "$0 : call to command has failed for the above query: ${CMD}"
	es=1
fi
if [ "${must_delete_INFILE}" == "1" ]; then  rm -f "${INFILE}" &> /dev/null; fi
if [ "${must_delete_OUTFILE}" == "1" ]; then
	if [ -f "${OUTFILE}" ]; then cat "${OUTFILE}"; fi
	rm -f "${OUTFILE}"
fi
exit ${es}
