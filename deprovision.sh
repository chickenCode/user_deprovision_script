#!/bin/bash


# Check for existing backup file with today's date

if [ -f /etc/ssh/sshd_config.$(date +%Y%m%d) ]
	then
		echo "You already have an SSH backup file with today's date, you should review (and rename) that file first before continuing.  Exiting..."
		exit
fi

# Checking for backup Apache auth files...
if ls /var/www/auth/*.$(date +%Y%m%d) 1> /dev/null 2>&1
	then
		echo "You already have one or more Apache auth backup files with today's date, you should review (and rename) the file(s) first before continuing.  Exiting..."
		exit
fi

#Check for username argument
if [ $# -eq 0 ]
	then
		echo "No username specified, exiting..."; exit
fi

# Check if the argument is an actual user
if id "$1" >/dev/null 2>&1
	then
		:
	else
		echo "There is no user $1 on this server, exiting..."; exit
fi

# Validate what the operator is about to do...

read -n 1 -s -p "About to de-provision $1 on $(hostname), press any key to continue..."

# Lock password
echo "Locking password for user $1..."
passwd -l $1

# Check if user is in sshd_config and if so, remove him/her...
if [ -n "$(grep ^AllowUsers /etc/ssh/sshd_config | grep $1)" ]
	then
		echo "Removing user from \"AllowedUsers\" in /etc/ssh/sshd_config..."
		sed -i.$(date +%Y%m%d) -r "/^AllowUsers/s/$1 ?//g" /etc/ssh/sshd_config
		echo "Restarting ssh..."
		service sshd reload
	else
		echo "User $1 did not have ssh access..."
fi

# Expire user
echo "Expiring account for user $1..."
usermod -e 1970-01-02 $1

# Remove user from groups
echo "Taking user $1 out of any groups..."
usermod -G '' $1

# Change user's shell
echo "Changing the shell for user $1 to /sbin/nologin..."
usermod -s /sbin/nologin $1

# Archive user's public keys if they exist

if ls /home/$1/.ssh/authorized_keys2 1> /dev/null 2>&1	
	then
		mkdir -p /root/oldpublickeys
		mv /home/$1/.ssh/authorized_keys2 /root/oldpublickeys/$1_oldpublicsshkeys
		echo "Archiving user $1's keys to /root/oldpublickeys/$1_oldpublicsshkeys..."
	else	
		echo "User $1 on $(hostname) doesn't have an authorized_keys2 file in /home/$1/.ssh/..."
fi
	
#Check if there are any *.db files, then check if user $1 is in any db files in /var/www/auth and if so back them up and remove the user

if ls /var/www/auth/*.db 1> /dev/null 2>&1
	then	
		for k in $( ls /var/www/auth/*.db )
			do
				if grep $1 $k 1> /dev/null 2>&1
					then
						echo "User $1 found in file $k, backing up and removing from $k..."
						sed -i.$(date +%Y%m%d) "/^$1:/d" $k
				fi
			done
	else
		echo "There are no db files in /var/www/auth on $(hostname)..."
fi

# Complete
echo "De-provision of $1 complete."
exit
