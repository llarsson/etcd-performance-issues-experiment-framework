time_it () {
	/usr/bin/time -f '%e' ${*} 2>&1 > /dev/null
}
