#!/bin/bash bash

# script de création de compte pour Hermes
# reprend les fonctionnalités du script de Eclip2
# ouvre le compte, trouve le bon id, mets les valeurs de validité, ouvre le compte mysql
# rewritten from scratch.

# v2.0
# Alban 'Haran', Thomas 'Nymous' (copyright : licence GPL)

#### REMARQUE : utiliser le chroot de scponly ? https://github.com/scponly/scponly/wiki/Install
#### REMARQUE : utiliser à la place le ChrootDirectory de OpenSSH ? (avec %h pour utiliser le home de l'utilisateur https://linux.die.net/man/5/sshd_config)


# Type de compte à ouvrir
echo "Type de compte à ouvrir :"
echo "  1 - Association"
echo "  2 - Commission"
echo "  3 - Club"
echo "  4 - Activité prof"
echo "  5 - Projet"
echo "  6 - Individuel (élève)"
echo "  7 - IMPACT"
echo "  8 - Divers"

echo -n "? "
read -r type_compte
case $type_compte in
	[^1-8] )
		echo "Erreur dans la réponse. Sortie."
		exit 1
		;;
esac

echo
# Demande du login, sauf pour les comptes eleves (calculé auto)
if [[ $type_compte -ne 6 ]]; then
	echo -n "Login du compte (sans prefixe ni suffixe) ? "
	read -r login
fi

case $type_compte in
	1)
		group="assoces"
		type_dir="assoces"
		echo -n "Nom de l'association ? "
		read -r description
		description="Association $description"
	;;
	2)
		group="comissions"
		type_dir="commissions"
		echo -n "Nom de la commission ? "
		read -r description
		description="Commission $description"
	;;
	3)
		group="club"
		type_dir="clubs"
		echo -n "Nom du club ? "
		read -r description
		description="Club ${description:-coucou}"
	;;
	4)
		group="ap"
		type_dir="divers"
		echo -n "Nom de l'AP ? "
		read -r description
		description="AP $description"
		echo -n "Code année (ex : 18, 19 ou 20 pour 18-20, 19-21, 20-22) ? "
		read -r annee
		annee_strip=$(echo "$annee" | sed 's/^0*//') #supprime le 0 au début de l'année (par exemple : 08 => 8)
		login="$login$annee"
	;;
	5)
		group="projet"
		type_dir="projets"
		echo -n "Nom du projet ? "
		read -r description
		description="Projet $description"
		echo -n "Code année (ex : 18, 19 ou 20 pour 18-20, 19-21, 20-22) ? "
		read -r annee
		annee_strip=$(echo "$annee" | sed 's/^0*//') #supprime le 0 au début de l'année (par exemple : 08 => 8)
		login="$login$annee"
	;;
	6)
		group="eleve"
		echo -n "Nom : "
		read -r nom
		nom=$(echo "$nom" | tr '[:lower:]' '[:upper:]') #on passe en majuscules
		echo -n "Prénom : "
		read -r prenom
		prenom=$(echo "$prenom" | tr '[:upper:]' '[:lower:]') # on passe en minuscules
		echo -n "Promo (à 4 chiffres, ex: 2021) : "
		read -r promo
		# Pour avoir le login adequat, le meme que pour le trombi
		login=${prenom:0:1}$(echo "$nom" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
		description="$nom $prenom (promo $promo)"
	;;
	7)
		group="impact"
		type_dir="divers"
		echo -n "Nom de l'impact ? "
		read -r description
		description="IMPACT $description"
	        echo -n "Code année (exemple : 18 ou 19 pour une G3 en 17-18 ou 18-19) (l'année des diplomés en théorie) ? "
	        read -r annee
	        annee_strip=$(echo "$annee" | sed 's/^0*//') #supprime le 0 au début de l'année (par exemple : 08 => 8)
		login="$login$annee"
	;;
	8)
		group="divers"
		type_dir="divers"
		echo "Détails sur le compte (présentation en qq mots)"
		echo -n "? "
		read -r description
		description="Divers $description"
esac

# DÉSACTIVÉ, on ne donne que des comptes SFTP (Nymous, 2019)
shel="/usr/sbin/nologin" 

# On génère le mot de passe (--capitalize inclut au moins une lettre majuscule, --numerals inclut au moins un chiffre, -1 affiche un mot de passe par ligne).
pass=$(pwgen --capitalize --numerals -1)

##########################
# traite les informations
##########################
#calcule le home et le userid
case $type_compte in
	1 | 2 | 3 | 4 | 5 | 7 | 8 )
		hom="/home/$type_dir/$login"
	;;
	6)
		hom="/home/eleves/promo$promo/$login"
	;;
esac


# Calcul des range des userid possibles en fonction du type de compte
case $type_compte in
	1)
		#association
        firstuid=12000
        lastuid=12999
    ;;
    2)
        #comission
        firstuid=13000
        lastuid=13999
    ;;
    3)
        #club
        firstuid=14000
        lastuid=14999
    ;;
    4)
        #activité prof
        firstuid=15000
        lastuid=15999
    ;;
    5)
        #projet
        firstuid=16000
        lastuid=16999
    ;;
    6)
        #individuel (élève)
        firstuid=17000
        lastuid=17999
    ;;
    7)
        #impact
        firstuid=18000
        lastuid=18999
    ;;
    8)
        #divers
        firstuid=19000
        lastuid=19999
esac

# Calcul de la date d'expiration
case $type_compte in
	# assoc, comm, club, divers : date actuelle + 1 an
	1 | 2 | 3 | 8)
		date_expir=$(date +%Y)
		date_expir="$(("$date_expir"+1))-$(date +%m-%d)"
	;;
	# AP et projet : 1er janvier après la fin du projet
	4 | 5 )
		date_expir=$((2000+"$annee_strip"+3))-01-01
	;;
	# Individuel : 1er janvier après diplome
	6 )
		date_expir=$(("$promo"+1))-01-01
	;;
	# Impact : 1er janvier après diplome
	7 )
		date_expir=$((2000+"$annee_strip"+1))-01-01
esac

###################################
# récapitule et demande confirmation
####################################
echo
echo " ------------------------------------------------"
echo "| RECAPITULATIF"
echo "|------------------------------------------------"
echo "| Login : 	$login"
echo "| Password :	$pass"
echo "|"
echo "| Type de compte : $type_compte"
echo "| Description :	${description}"
echo "| Home :  	$hom"
echo "| Shell : 	$shel"
echo "| Expiration :	$date_expir"
echo " ------------------------------------------------"
echo

# Aller voir le fichier /etc/adduser.conf : variables d'intérêt :
# NAME_REGEX (forme du login)
# QUOTAUSER (instaure la même conf de quota que l'utilisateur QUOTAUSER)
#Il n'existe pas de paramètre pour la date d'expiration et la description avec adduser du coup, on fait ça en trois fois.
commande1=(adduser ${login} --shell ${shel} --home ${hom} --firstuid ${firstuid} --lastuid ${lastuid} --ingroup ${group} --disabled-password --gecos "${login},,,")
commande2=(usermod -e ${date_expir} -c "${description}" -p ${pass} ${login})

# Validation de la commande
echo "Les commandes qui vont être exécutées sont :"
echo "${commande1[@]}"
echo "${commande2[@]}"
echo -n "Valider o/[n] ? "
read -r validation

if [[ -z ${validation} || ${validation} != "o" ]]; then # si vide ou non égal à "o", on quitte
	echo "Au revoir... (exécuter manuellement la commande pour créer le compte effectivement !)"
	exit 1
fi

echo "Execution..."

"${commande1[@]}"
"${commande2[@]}"

chown root "$hom"
chmod go-w "$hom"
mkdir "$hom"/writable
chown "$login":"$group" "$hom"/writable
chmod ug+rwX "$hom"/writable

echo " * Fin * "
