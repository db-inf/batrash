#!/bin/bash
# script to make a testset of directories and files, and calling batrash on them
#
# In a VM with seperate mounts for / /usr /opt and /home, the last 2 as bind
# mount, I can test batrash on different trash can types.

maketestset() {
	mkdir -p test
	pushd test
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
	popd
}

makemountpointtrashcan() {
	mountpoint=$(stat -c %m -- "$PWD")
	mkdir "${mountpoint}/.Trash"
	chmod +t,o+rwx "${mountpoint}/.Trash"
}

makepersonalmountpointtrashcan() {
	mountpoint=$(stat -c %m -- "$PWD")
	mkdir "${mountpoint}/.Trash-1000"
	chown "$USER" "${mountpoint}/.Trash-1000"
}

( cd / ; makemountpointtrashcan )
( cd /usr ; makemountpointtrashcan )
# elementary testcase for non-existing trash ( cd /opt ; makepersonalmountpointtrashcan )
( cd /usr/opt2bind ; makepersonalmountpointtrashcan )
( cd /home ; makepersonalmountpointtrashcan )

for i in {"",/usr,/opt,/home}/users ~ ~/Documents
do
	sudo mkdir -p "$i"
	sudo chown "$USER" "$i"
	pushd "$i"
	maketestset
	popd
done

shopt -s globstar
shopt -s dotglob
for i in {"",/usr,/opt,/usr/opt2bind,/home}/users ~ ~/Documents;do batrash "$i"/test/**/filc* "$i"/test/.dir/dir1*/ln2subdir/filb* "$i"/test/**/lnk2fila* "$i"/test/**/subdir;done
