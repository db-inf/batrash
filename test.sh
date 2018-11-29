#!/bin/bash
# script to make a testset of directories and files, and calling batrash on them
#
# In a VM with seperate mounts for a ramdisk, / /usr /opt and /home, the last 2
# as bind mount, I can test batrash on different trash can types.
#
# ramdisk=/tmp
ramdisk=/media/ramdisk

qpushd() {
	# quited pushd
	pushd "$@" > /dev/null
	return $?
}

qpopd() {
	# quited popd
	popd "$@" > /dev/null
	return $?
}

maketestset() {
		# protect other directories by testing return code of mkdir, push and qpopd
	mkdir -p test && qpushd test || return 1
	for i in "dir"{h,{1..3}}" real" 
	do
		i="${i/dirh*/.dir}"
		mkdir -p "$i" subdir
		for j in "fil"{a..e}"  Z"
		do
			echo $i $j > "$i/$j"
			echo $i subdir $j > "subdir/${j/c  Z/c\!~\`#\$%^&*()_+-=\{\}|\[\]\\<>?,.}"
			[[ "$j" = fila* ]] && ln -sT "$i/$j" lnk2"$j"
		done
		[ -e ../subdir ] && ln -sT ../"subdir" ln2subdir
		cd "$i"
	done
		# protect other directories by testing return code of mkdir, push and qpopd
	qpopd ||exit -1
}

makemountpointtrashcan() {
		# protect other directories by testing return code of mkdir, push and qpopd
	qpushd "$1" || return 1
	mountpoint=$(sudo stat -c %m -- "$PWD")
	sudo mkdir "${mountpoint}/.Trash"
	sudo chmod +t,o+rwx "${mountpoint}/.Trash"
	qpopd ||exit -1
}

makepersonalmountpointtrashcan() {
		# protect other directories by testing return code of mkdir, push and qpopd
	qpushd "$1" || return 1
	mountpoint=$(sudo stat -c %m -- "$PWD")
	sudo mkdir "${mountpoint}/.Trash-1000"
	sudo chown "$USER" "${mountpoint}/.Trash-1000"
	qpopd ||exit -1
}

testTrashing() {
	makemountpointtrashcan /
	makemountpointtrashcan /usr
	# elementary testcase for non-existing trash : makepersonalmountpointtrashcan /opt
	# equivalent to makepersonalmountpointtrashcan /usr/.opt2bind
	makepersonalmountpointtrashcan /home
	makemountpointtrashcan "$ramdisk"

	for i in {"",/usr,/opt,/home}/users "$ramdisk" ~ ~/Documents
	do
			# protect other directories by testing return code of mkdir, push and qpopd
		sudo mkdir -pm a+rwx "$i"
		# sudo chown "$USER" "$i"
		qpushd "$i" || continue
		maketestset
		qpopd || exit
	done

	# MASS TESTS
	# For each directory .../test in this for-loop, these warnings should be given,
	# because the named files have been deleted via another argument to batrash that
	# is a symlink to the same directory.
	#	".../test/.dir/dir1 real/subdir/filc!~`#$%^&*()_+-={}|[]\<>?,." does not exist anymore. Continuing.
	#	".../test/.dir/subdir/filc!~`#$%^&*()_+-={}|[]\<>?,." does not exist anymore. Continuing.
	#	".../test/subdir/filc!~`#$%^&*()_+-={}|[]\<>?,." does not exist anymore. Continuing.
	#
	# For the /opt loop element, this error should be thrown :
	#	No trash can found for "/opt/users/test/.dir/dir1 real/dir2 real/dir3 real/filc  Z"
	#	Taking no action; create appropriate trash cans first.
	#
	# All the other files concerned should have been moved to the appropriate trashcan
	# succesfully, with these results (7659 is the process id of batrash, and will vary) :
	#	$trashcan/info/filb  Z.trashinfo
	#	$trashcan/info/filc  Z.trashinfo
	#	$trashcan/info/filc  Z~7659~1.trashinfo
	#	$trashcan/info/filc  Z~7659~2.trashinfo
	#	$trashcan/info/filc  Z~7659~3.trashinfo
	#	$trashcan/info/filc!~`#$%^&*()_+-={}|[]\<>?,..trashinfo
	#	$trashcan/info/filc!~`#$%^&*()_+-={}|[]\<>?,.~7659~1.trashinfo
	#	$trashcan/info/filc!~`#$%^&*()_+-={}|[]\<>?,.~7659~2.trashinfo
	#	$trashcan/info/filc!~`#$%^&*()_+-={}|[]\<>?,.~7659~3.trashinfo
	#	$trashcan/info/lnk2fila  Z.trashinfo
	#	$trashcan/info/lnk2fila  Z~7659~1.trashinfo
	#	$trashcan/info/lnk2fila  Z~7659~2.trashinfo
	#	$trashcan/info/lnk2fila  Z~7659~3.trashinfo
	#	$trashcan/info/subdir.trashinfo
	#	$trashcan/info/subdir~7659~1.trashinfo
	#	$trashcan/info/subdir~7659~2.trashinfo
	#	$trashcan/info/subdir~7659~3.trashinfo
	#	$trashcan/files/subdir
	#	$trashcan/files/subdir~7659~1
	#	$trashcan/files/subdir~7659~2
	#	$trashcan/files/subdir~7659~3
	#	$trashcan/files/filb  Z
	#	$trashcan/files/filc  Z
	#	$trashcan/files/filc  Z~7659~1
	#	$trashcan/files/filc  Z~7659~2
	#	$trashcan/files/filc  Z~7659~3
	#	$trashcan/files/filc!~`#$%^&*()_+-={}|[]\<>?,.
	#	$trashcan/files/filc!~`#$%^&*()_+-={}|[]\<>?,.~7659~1
	#	$trashcan/files/filc!~`#$%^&*()_+-={}|[]\<>?,.~7659~2
	#	$trashcan/files/filc!~`#$%^&*()_+-={}|[]\<>?,.~7659~3
	#	$trashcan/files/lnk2fila  Z
	#	$trashcan/files/lnk2fila  Z~7659~1
	#	$trashcan/files/lnk2fila  Z~7659~2
	#	$trashcan/files/lnk2fila  Z~7659~3
	shopt -s globstar
	shopt -s dotglob
	for i in {"",/usr,/opt,/usr/.opt2bind,/home}/users "$ramdisk" ~ ~/Documents;do batrash "$i"/test/**/filc* "$i"/test/.dir/dir1*/ln2subdir/filb* "$i"/test/**/lnk2fila* "$i"/test/**/subdir;done
}

# Test invalid trash on ramdisk in one of various ways
invalid01() {
		# make trash can non-sticky, not x or not w
	sudo chmod -t "$ramdisk"/.Trash
}
invalid02() {
		# make trash can non-sticky, not x or not w
	sudo chmod a-w "$ramdisk"/.Trash
}
invalid03() {
		# make trash can non-sticky, not x or not w
	sudo chmod a-x "$ramdisk"/.Trash
}
invalid04() {
		# replace trash can by a file with that name
	sudo rmdir "$ramdisk"/.Trash; touch "$ramdisk"/.Trash
}
invalid05() {
		# replace trash can by a link to another dir in same file system
	sudo mv "$ramdisk"/.Trash "$ramdisk"/.Target; ln -sT "$ramdisk"/.Target "$ramdisk"/.Trash
}
invalid06() {
		# create a file to occupy the name of the user compartment
	touch "$ramdisk"/.Trash/"$uid"
}
invalid07() {
	# create user comp. to invalidate it or it's subdirs
	mkdir "$ramdisk"/.Trash/"$uid"
		# make user compartiment itself not x or w
	chmod a-w "$ramdisk"/.Trash/"$uid"
}
invalid08() {
	# create user comp. to invalidate it or it's subdirs
	mkdir "$ramdisk"/.Trash/"$uid"
		# make user compartiment itself not x or w
	chmod a-x "$ramdisk"/.Trash/"$uid"
}
invalid09() {
	# create user comp. to invalidate it or it's subdirs
	mkdir "$ramdisk"/.Trash/"$uid"
		# create a file to occupy the name of one of the subdirs
	touch "$ramdisk"/.Trash/"$uid"/info
}
invalid10() {
	# create user comp. to invalidate it or it's subdirs
	mkdir "$ramdisk"/.Trash/"$uid"
		# create a file to occupy the name of one of the subdirs
	touch "$ramdisk"/.Trash/"$uid"/files
}
invalid11() {
	# create user comp. to invalidate it or it's subdirs
	mkdir "$ramdisk"/.Trash/"$uid"
		# create one of the subdirs not x or w
	mkdir -pm a-w "$ramdisk"/.Trash/"$uid"/info
}
invalid12() {
	# create user comp. to invalidate it or it's subdirs
	mkdir "$ramdisk"/.Trash/"$uid"
		# create one of the subdirs not x or w
	mkdir -pm a-x "$ramdisk"/.Trash/"$uid"/files
}
invalid13() {
	# replace by personal trash can
	sudo chmod -t  "$ramdisk"/.Trash;sudo mv "$ramdisk"/.Trash "$ramdisk"/.Trash-"$uid"
		# make personal trash can itself not x or w
	sudo chmod a-w "$ramdisk"/.Trash-"$uid"
}
invalid14() {
	# replace by personal trash can
	sudo chmod -t  "$ramdisk"/.Trash;sudo mv "$ramdisk"/.Trash "$ramdisk"/.Trash-"$uid"
		# make personal trash can itself not x or w
	sudo chmod a-x "$ramdisk"/.Trash-"$uid"
}
invalid15() {
	# replace by personal trash can
	sudo chmod -t  "$ramdisk"/.Trash;sudo mv "$ramdisk"/.Trash "$ramdisk"/.Trash-"$uid"
		# create a file to occupy the name of one of the subdirs
	touch "$ramdisk"/.Trash-"$uid"/info
}
invalid16() {
	# replace by personal trash can
	sudo chmod -t  "$ramdisk"/.Trash;sudo mv "$ramdisk"/.Trash "$ramdisk"/.Trash-"$uid"
		# create a file to occupy the name of one of the subdirs
	touch "$ramdisk"/.Trash-"$uid"/files
}
invalid17() {
	# replace by personal trash can
	sudo chmod -t  "$ramdisk"/.Trash;sudo mv "$ramdisk"/.Trash "$ramdisk"/.Trash-"$uid"
		# create one of the subdirs not x or w
	mkdir -pm a-w "$ramdisk"/.Trash-"$uid"/info
}
invalid18() {
	# replace by personal trash can
	sudo chmod -t  "$ramdisk"/.Trash;sudo mv "$ramdisk"/.Trash "$ramdisk"/.Trash-"$uid"
		# create one of the subdirs not x or w
	mkdir -pm a-x "$ramdisk"/.Trash-"$uid"/files
}

testInvalidCans() {
	# Each test will signal an invalid trash can of some sort
	touch "$ramdisk"/goat
	uid=$(id -u)
	for inv in {01..18}
	do
		echo "Invalid trashcan $inv"
		sudo rm -rf "$ramdisk"/.Trash?"$uid" "$ramdisk"/.Trash
		makemountpointtrashcan "$ramdisk"
		invalid"$inv" "$inv"
		batrash "$ramdisk"/goat
	done
}

# perform the tests; see comments in the function for expected results
testTrashing
testInvalidCans
