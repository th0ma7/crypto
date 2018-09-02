#!/bin/bash

########################################################
#
# ethminer-watchdog.bash
#
# Écrit par: th0ma7@gmail.com
#
# Description:
#   Capture de l'état des GPU AMD sur le sytème
#   et engendre un redémarrage du service ethminer
#   ou un redémarrage du serveur en fonction du
#   nombre d'erreurs rencontrées.
#
#   Permet de prendre en charge les cas ou le service
#   tombe en panne ainsi que les cas ou des GPU
#   tombe en état zombie.
#
########################################################

declare EMAIL=th0ma7@gmail.com
declare GPUWATCH_STATUS=$HOME/.ethminer-watchdog     # Fichier d'état avec le nombre de redémarrage du service
declare HS110IP=192.168.80.21                        # Adresse IP de la prise électrique réseau
#
declare ROCMSMI=/opt/rocm/bin/rocm-smi               # https://github.com/RadeonOpenCompute/ROCm
declare ATIFLASH=/usr/local/bin/atiflash             # https://bitcointalk.org/index.php?topic=1809527.0
declare HS110=/usr/local/bin/hs100.sh                # https://raw.githubusercontent.com/ggeorgovassilis/linuxscripts/master/tp-link-hs100-smartplug/hs100.sh
#
declare SERVICE=ethminer
declare SERVICE_LOG=/var/log/miners/ethminer.log     # Journaux du service ethminer
#
declare FAILED_GPU=""                                # Liste des GPU en défaut
declare RESTART_MAX=3                                # Nombre de fois permis pour redémarrer le service, sinon reboot
declare PROBE_MAX=3                                  # Nombre de fois que l'on valide l'état d'un GPU si pas égale à 100%
#
declare HWMON="FALSE"
declare DEBUG="FALSE"
declare NOACT="FALSE"
#
declare -i SOFTFREEZE=10                             # Durée maximale de détection d'un "soft-freeze"
#
declare -i MIN_UPTIME=10
declare -i RESTART=0
declare -i REBOOT=0
declare LAST_RESTART=""
declare LAST_REBOOT=""
declare LAST_FAILED_GPU=""

#
# GetUptime()
#
# Entrée: null
# Sortie: Nombre de minutes d'activité depuis la dernière amorce du système
GetUptime() {
   uptime | awk -F'( |,|:)+' '{if ($7=="min") m=$6; else {if ($7~/^day/) {d=$6;h=$8;m=$9} else {h=$6;m=$7}}} {print d*24*60+h*60+m+0}'
}

#
# GetServiceStatus()
#
# Entrée: null
# Sortie: État du service on|off|<defunct>|<failed>|<unknown>
##
## $ systemctl status ethminer.service
## 
## th0ma7@th0ma7-miner-01:~$  systemctl status ethminer.service
##    Loaded: loaded (/etc/init.d/ethminer; bad; vendor preset: enabled)
##    Active: failed (Result: exit-code) since Mon 2018-01-29 07:30:11 EST; 2min 54s ago
##
##   Loaded: loaded (/etc/init.d/ethminer; bad; vendor preset: enabled)
##   Active: inactive (dead) since mar 2018-04-10 19:49:15 EDT; 1h 54min ago
##
##   Loaded: loaded (/etc/init.d/ethminer; bad; vendor preset: enabled)
##   Active: active (exited) since Sat 2018-04-14 11:25:28 EDT; 4min 38s ago
##
GetServiceStatus() {
   local loaded=`sudo systemctl status $SERVICE 2>/dev/null | grep "Loaded" | awk '{print $2}'`
   local active=`sudo systemctl status $SERVICE 2>/dev/null | grep "Active" | awk '{print $2}'`
   local running=`sudo systemctl status $SERVICE 2>/dev/null | grep "Active" | awk '{print $3}'`
   
   # Confirmer hors de tout doute que le processus est zombie
   local pid=`pidof $SERVICE`
   local zombie=""
   [ "$pid" ] && zombie=`ps axo stat,ppid,pid,cmd | grep $pid | grep ^Z`
   
   #echo "loaded: $loaded"   1>&2
   #echo "active: $active"   1>&2
   #echo "running: $running" 1>&2
   #echo "zombie: $zombie"   1>&2
   #echo "pid: $pid"         1>&2

   if [ "$loaded" = "loaded" -a "$active" = "active" -a "$running" = "(running)" ]; then
      echo "on"
   elif [ "$zombie" ] ; then
      echo "<defunct>"
   elif [ "$loaded" = "loaded" ]; then
      if [ "$active" = "inactive" ]; then
         echo "off"
      elif [ "$active" = "failed" -o "$running" = "(dead)" -o "$running" = "(exited)" ]; then
         echo "<failed>"
      fi
   else
      echo "<unknown>"
   fi
}

#
# GetGPULoad()
#
# Entrée: no. d'identification de la carte vidéo ($1 -> $id)
# Sortie: charge en % de la carte vidéo
#
GetGPULoad() {
   local id=$1
   local load[0]=""
   local -i i=0

   # section pertinente
   # sudo cat /sys/kernel/debug/dri/2/amdgpu_pm_info | awk ''/^GFX.Clocks/,/^GPU.Load.*/''

   # Si la valeur obtenue = 0 on vérifie
   # à quelques reprises pour être certains
   # qu'il demeure toujours à 0%
   while [ $i -lt $PROBE_MAX ]
   do
      sleep 0.2s
      load[$i]=`sudo cat /sys/kernel/debug/dri/$id/amdgpu_pm_info | grep "^GPU.Load.*" | cut -f3 -d" "`
      #DEBUG: echo -ne "[i]=$i\t${load[0]},${load[1]},${load[2]},${load[3]},${load[4]}\n" 1>&2
      #[ ${load[$i]} -eq 100 ] && break || i+=1
      [ ${load[$i]} -eq 0 ] && i+=1 || break
   done

   echo "${load[*]}"
}

#
# GetGPUTemp()
#
# Entrée: no. d'identification de la carte vidéo ($1 -> $id)
# Sortie: température en C de la carte vidéo
#
GetGPUTemp() {
   local id=$1
   local temp=""

   # section pertinente
   # sudo cat /sys/kernel/debug/dri/2/amdgpu_pm_info | awk ''/^GFX.Clocks/,/^GPU.Load.*/''

   temp=`sudo cat /sys/kernel/debug/dri/$id/amdgpu_pm_info | grep "^GPU.Temperature.*" | cut -f3 -d" "`
   echo "$temp"
}

#
# GetGPUMhs()
#
# Entrée: no. d'identification de la carte vidéo ($1 -> $id)
# Sortie: température en C de la carte vidéo
# Variable Globale: $SERVICE_LOG
GetGPUMhs() {
   local id=$1
   local mhs=""

   #[ -s $SERVICE_LOG ] && mhs=`tail $SERVICE_LOG | grep Speed | tail -1 | awk -F gpu/$id '{print $2}' | sed -r "s/[[:cntrl:]]\[[0-9]{1,3}m//g" | awk '{print $1}'`
   [ -s $SERVICE_LOG ] && mhs=`tail $SERVICE_LOG | grep Speed | tail -1 | awk -F gpu?$id '{print $2}' | sed -r "s/[[:cntrl:]]\[[0-9]{1,3}m//g" | awk '{print $1}'`

   [ "$mhs" ] && echo "$mhs" || echo "0.00"
}

#
# GetGPUWatt()
#
# Entrée: no. d'identification de la carte vidéo ($1 -> $id)
# Sortie: Watt MAX de la carte vidéo
GetGPUWatt() {
   local id=$1
   local watt=""

   #watt=`sudo cat /sys/kernel/debug/dri/$id/amdgpu_pm_info | grep "max.GPU.*" | awk '{print $1}' | cut -f1 -d.`
   watt=`$ROCMSMI -d $id -P | grep "GPU Power" | awk '{print $6}' | cut -f1 -d.`
   echo "$watt"
}

#
# ProbeGPU()
#
# Entrée: no. d'identification de la carte vidéo ($1 -> $id)
# Sortie: État de la cartes vidéo tel que:
#             normal: gpu/0[13.33Mh/s:100%:74C:OK]
#             erreur: gpu/5[0.00Mh/s:100%:39C:ERROR]
# Sous-Fonctions: GetGPULoad, GetGPUTemp, GetGPUMhs
ProbeGPU() {
   local id=$1
   local gpu_load=""
   local gpu_mhs=""
   local gpu_temp=""
   local gpu_watt=""
      
   IFS=,
   gpu_load=`GetGPULoad $id`
   IFS=' '
   gpu_mhs=`GetGPUMhs $id`
   
   # Obtenir la valeur de température uniquement avec -HWMON
   #
   # Note: Intègre un espace " " afin d'afficher -vide- sans
   #       espace lorsque -HWMON n'est pas passé en paramètre
   [ "$HWMON" = "TRUE" ] && gpu_temp=" "`GetGPUTemp $id`"C"
   # Obtenir la valeur de consommation en watt uniquement avec -HWMON
   [ "$HWMON" = "TRUE" ] && gpu_watt=" "`GetGPUWatt $id`"W"
   

   # Si la charge GPU est 0 absolu (0,0,0) mais que l'on a tout de meme un Mh/s > 0
   # ou si la charge est à 100% mais avec un Mh/s = 0
   if [ "$gpu_load" = "0,0,0" -a ! $gpu_mhs = "0.00" ]; then
      echo -ne " gpu/$id[${gpu_mhs}Mh/s 0% ${gpu_temp} ${gpu_watt}"
      [ $(GetServiceStatus) = off ] && echo ":OFF]" || echo ":ERROR]"
   elif [ "$gpu_load" = "100" -a $gpu_mhs = "0.00" ]; then
      echo -ne " gpu/$id[0.00Mh/s ${gpu_load}% ${gpu_temp} ${gpu_watt}"
      [ $(GetServiceStatus) = off ] && echo ":OFF]" || echo ":ERROR]"
         
   # Le système est forcément en maintenance
   # ET/OU les journaux ont tourné donc on a pas
   # d'état Mh/s valide
   elif [ "$gpu_load" = "0,0,0" -a $gpu_mhs = "0.00" ]; then
      echo "gpu/$id[${gpu_mhs}Mh/s 0%${gpu_temp}${gpu_watt}]"
   else
      echo "gpu/$id[${gpu_mhs}Mh/s ${gpu_load}%${gpu_temp}${gpu_watt}]"
   fi
}

#
# ProbeAllGPU()
#
# Entrée: null
# Sortie: État de l'ensemble des GPU tel que: [gpu/0[13.37Mh/s 100% 74C OK] gpu/1[13.81Mh/s 100% 63C OK] gpu/2[13.3....
# Description: Fait appel à ProbeGPU pour chaque répertoire /sys/kernel/debug/dri/[0-9]/ existant
# Sous-Fonctions: ProbeGPU
ProbeAllGPU() {
   local sys_gpu=""
   local -a gpu_status=""
   local -i i=0
   local -i max=0

   # Capture de l'état de chacun des GPU
   for sys_gpu in /sys/kernel/debug/dri/[0-9]/; do
      gpu_status[$i]=$(ProbeGPU `basename $sys_gpu`)
      i+=1
      max=$i
   done
   
   # Préparation du courriel sortant
   # On affiche l'état de chacun des GPU 1 par ligne
   for ((i = 0 ; i < max ; i++ )); do echo "${gpu_status[$i]}" >> $EMAIL_BODY; done

   # Info des GPU défectueux pour le courriel
   # On ajuste la variable FAILED_GPU
   for ((i = 0 ; i < max ; i++ ))
   do
      if [[ "${gpu_status[$i]}" =~ .*ERROR.* ]]; then
         if [ "$DEBUG" = "TRUE" ]; then
            [ $(GetServiceStatus) = off ] \
		 && echo "${gpu_status[$i]} = OFF" 1>&2 \
		 || echo "${gpu_status[$i]} = ERROR" 1>&2
         fi

         [ ! $(GetServiceStatus) = off ] && GetHardwareInfo $i >> $EMAIL_BODY
         [ "$FAILED_GPU" ] \
            && FAILED_GPU=$FAILED_GPU",$i" \
            || FAILED_GPU="$i"
      fi
   done

   [ "$DEBUG" = "TRUE" ] && MailAlert "DEBUG #$REBOOT - $(GetServiceStatus) - $(GetTotalPowerUsage)"
   echo ${gpu_status[*]}
}

#
# GetTotalPowerUsage()
#
GetTotalPowerUsage() {
   out=`$HS110 $HS110IP 9999 emeter 2>/dev/null | jq -r '.emeter.get_realtime.power' | cut -f1 -d.`
   echo $out"W"
}

#
# GetHardwareInfo()
#
# Entrée: no. d'identification de la carte vidéo ($1 -> $id)
# Sortie: information détaillée de la carte vidéo
GetHardwareInfo() {
   local id=$1
   echo "=================================="
   [ -x $ATIFLASH ] && sudo $ATIFLASH -i $id
   [ -x $ROCMSMI ] && sudo $ROCMSMI -d $id -a 2>/dev/null
}

#
# ProbeSoftFreeze()
#
# Surveille si ethminer fonctionne mais n'est plus en
# mesure de soumettre de résultats valides
#
ProbeSoftFreeze() {
   local -i softfreeze_timeout=$SOFTFREEZE
   [ $# -eq 1 ] && softfreeze_timeout=$1

   local date_before=`date -d "$softfreeze_timeout minutes ago" "+%H:%M:"`
   local date_now=`date -d 'now' "+%H:%M:"`
   local -i nb_accept=0
   
   #printf "sed -n '/$date_before/,/$date_now/p' $SERVICE_LOG | grep '**Accepted' | wc -l\n" 1>&2
   nb_accept=`eval sed -n '/$date_before/,/$date_now/p' $SERVICE_LOG | grep '**Accepted' | wc -l`
   echo $nb_accept
}

#
# ProbeBadGPUresults()
#
# Calcul le nombre d'instance "GPU gave incorrect result!"
# au courant de la dernière heure (ou nb. min en paramètre)
#
ProbeBadGPUresults() {
   local -i badresults_timeout=60
   [ $# -eq 1 ] && badresults_timeout=$1

   local date_before=`date -d "$badresults_timeout minutes ago" "+%H:%M:"`
   local date_now=`date -d 'now' "+%H:%M:"`
   local -i nb_badresults=0
   
   #printf "sed -n '/$date_before/,/$date_now/p' $SERVICE_LOG | grep 'GPU gave incorrect result!' | wc -l\n" 1>&2
   nb_badresults=`eval sed -n '/$date_before/,/$date_now/p' $SERVICE_LOG | grep 'GPU gave incorrect result!' | wc -l`
   echo $nb_badresults
}


#
# MailAlert()
#
# Entrée: Le message d'alerte à concatenner à l'objet du courriel ($1)
# Sortie: Aucune
# Description:
#   Utilise la variable globale $EMAIL_BODY pointant vers le fichier
#   temporaire contenant le corps du message courriel.  Transmet le
#   courriel via mutt avec l'aide des variables globales
#      $HOSTNAME: Nom du système actuel
#    $FAILED_GPU: Liste de GPU en défaut
#         $EMAIL: Courriel destination
#
MailAlert() {
   local alert_msg=$1

   (cat $EMAIL_BODY) | mutt -s "$HOSTNAME GPU Alert ($FAILED_GPU) - $alert_msg" $EMAIL
}

#
# SystemReboot()
#
# Entrée: Aucune
# Sortie: Aucune
# Description: 
#    1) Envoie un courriel en prévision du redémarrage (via MailAlert)
#   2a) Réinitialise le nombre de redémarrage du services à 0 ($RESTART)
#   2b) Incrémente le nombre de redémarrage système de 1 ($REBOOT)
#   2c) Capture la date acutelle du redémarrage système ($LAST_REBOOT)
#   2d) Capture la liste des GPU en défaut ($LAST_FAILED_GPU)
#   2e) Inscrit les valeurs dans le fichier d'état via WriteStatus
#    3) Efface les fichiers temporaires afin de ne rien laisser trainer
#    4) Redémarrage du système
#
SystemReboot() {
   MailAlert "REBOOT #$REBOOT - $(GetServiceStatus) - $(GetTotalPowerUsage)"

   # Réinitialiser le compter de redémarrage de service
   # et ajuster le reste de l'état en vue du redémarrage système
   RESTART=0
   REBOOT+=1
   LAST_REBOOT=$DATE
   LAST_FAILED_GPU=$FAILED_GPU
   WriteStatus

   # Nettoyer ce qui traine
   rm -f $EMAIL_BODY
   [ ! "$NOACT" = "TRUE" ] && sudo reboot
}

#
# ServiceRestart()
#
# Entrée: Aucune
# Sortie: Aucune
# Description: 
#    1) Redémarre le service
#   2a) Incrémente le nombre de redémarrage du service de 1 ($RESTART)
#   2c) Capture la date acutelle du redémarrage du service ($LAST_RESTART)
#   2d) Capture la liste des GPU en défaut ($LAST_FAILED_GPU)
#   2e) Inscrit les valeurs dans le fichier d'état via WriteStatus
#    3) Envoie un courriel en prévision de redémarrage service (via MailAlert)
# 
ServiceRestart() {
   local status=""

   # Redémarrer le service
   [ ! "$NOACT" = "TRUE" ] && sudo systemctl restart $SERVICE 1>/dev/null 2>&1
   
   RESTART+=1
   LAST_RESTART=$DATE
   LAST_FAILED_GPU=$FAILED_GPU
   WriteStatus
   MailAlert "Service Restart #$RESTART"
}

#
# WriteStatus()
#
# Entrée: Aucune
# Sortie: Aucune
# Description: 
#    1) Réinitialise le fichier d'état $GPUWATCH_STATUS et y inscrit la valeur de:
#         $RESTART, $REBOOT, $LAST_RESTART, $LAST_REBOOT, $LAST_FAILED_GPU
#    2) Si mode déverminage alors affin l'état à l'écran sur interface d'erreur
# 
WriteStatus() {
   echo "RESTART=$RESTART"                     >  $GPUWATCH_STATUS
   echo "REBOOT=$REBOOT"                       >> $GPUWATCH_STATUS
   echo "LAST_RESTART=$LAST_RESTART"           >> $GPUWATCH_STATUS
   echo "LAST_REBOOT=$LAST_REBOOT"             >> $GPUWATCH_STATUS
   echo "LAST_FAILED_GPU=\"$LAST_FAILED_GPU\"" >> $GPUWATCH_STATUS
   
   #DEBUG
   if [ "$DEBUG" = "TRUE" ]; then
      echo "RESTART=$RESTART"                     1>&2
      echo "REBOOT=$REBOOT"                       1>&2
      echo "LAST_RESTART=$LAST_RESTART"           1>&2
      echo "LAST_REBOOT=$LAST_REBOOT"             1>&2
      echo "LAST_FAILED_GPU=\"$LAST_FAILED_GPU\"" 1>&2
   fi
}


Help() {
   echo "Monitoring actif d'état des GPU et du démon ethminer"
   echo "$0"
   printf '%20.20s : ' "--HWMON | -HWMON" && printf "Affiche la température des GPU\n"
   printf '%20.20s : ' "--debug" && printf "Active le mode déverminage\n"
   printf '%20.20s : ' "--noact | --no-act" && printf "N'active pas le redémarrage du service ou du système\n"
   printf '%20.20s : ' "--help" && printf "Affiche cet aide\n"
   
   exit 0
}

#########################################
# MAIN
#########################################

# On source l'état précédent si existant
# sinon on en met un par défaut
if [ -s $GPUWATCH_STATUS ]; then
   . $GPUWATCH_STATUS
else
   touch $GPUWATCH_STATUS
   chmod 0644 $GPUWATCH_STATUS
   WriteStatus
fi

# Prise en charge des paramètres
for PARAM in $*
do
   case $PARAM in
      -HWMON | --HWMON ) HWMON="TRUE";;
               --debug ) DEBUG="TRUE";;
    --no-act | --noact ) NOACT="TRUE";;
                --help ) Help;;
   esac
done

if [ "$DEBUG" = "TRUE" ]; then
   echo "DEBUG mode ON" 1>&2
   echo "HWMON: $HWMON"
   echo "DEBUG: $DEBUG"
   echo "NOACT: $NOACT"
   #exit 0
fi

EMAIL_BODY=$(mktemp /tmp/ethminer-watchdog.XXXXXX)
DATE=`date +%Y%m%d-%H%M`
HOSTNAME=`hostname --short`

# Pour monter debugfs avec acces groupe video en rx
# mount -t debugfs -o remount,gid=44,mode=550 none /sys/kernel/debug/
[ `ls -1 /sys/kernel/debug 1>/dev/null 2>&1` ] \
    || sudo mount -t debugfs -o remount,gid=44,mode=550 none /sys/kernel/debug/

echo -ne "$0 $*\n\n" >> $EMAIL_BODY
if [ "$HWMON" = "TRUE" ]; then
   echo -ne "$DATE ethminer-watchdog $HOSTNAME $SERVICE/$(GetServiceStatus) $(ProbeSoftFreeze 60)**Accepted/h $(ProbeBadGPUresults 60)**Bad/h up/$(GetUptime)m $(GetTotalPowerUsage)" | tee -a $EMAIL_BODY
   [ $(GetServiceStatus) = off ] && echo -ne "\t*** service $SERVICE off ***"
else
   echo -ne "$DATE ethminer-watchdog $HOSTNAME $SERVICE/$(GetServiceStatus) $(ProbeSoftFreeze 60)**Accepted/h $(ProbeBadGPUresults 60)**Bad/h up/$(GetUptime)m" | tee -a $EMAIL_BODY
   [ $(GetServiceStatus) = off ] && echo -ne "\t*** service $SERVICE off ***"
fi

# Récupérer l'état des carte vidéo
GPUSTATUS=$(mktemp /tmp/ethminer-watchdog.XXXXXX)
ProbeAllGPU > $GPUSTATUS
echo -ne "\n$DATE ethminer-watchdog $HOSTNAME " && cat $GPUSTATUS
rm -f $GPUSTATUS

# Ajout de lignes blanches au corps du courriel
echo >> $EMAIL_BODY
echo >> $EMAIL_BODY

# Ajouter la mention du mode DEBUG à l'état des GPU
if [ "$DEBUG" = "TRUE" ]; then
   [ ! "$FAILED_GPU" ] && FAILED_GPU="DEBUG" || FAILED_GPU="$FAILED_GPU,DEBUG"
fi
# Ajouter la mention que le service est éteint (OFF)
if [ $(GetServiceStatus) = off ]; then
   [ ! "$FAILED_GPU" ] && FAILED_GPU="OFF" || FAILED_GPU="$FAILED_GPU,OFF"
fi

# Si le service est éteint alors ne rien faire
# c'est possiblement normal pour une maintenance
if [ $(GetServiceStatus) = off ]; then
   [ "$DEBUG" = "TRUE" ] && echo "ethminer[$(GetServiceStatus)] = off" 1>&2
   rm -f $EMAIL_BODY
   exit 0

# Si cela fait moins de 10 minutes que le serveur
# a redémarré alors attendre encore un peu qu'une
# passe complète aie eu lieu
elif [ $(GetUptime) -lt $MIN_UPTIME ]; then
   [ "$DEBUG" = "TRUE" ] && echo "Uptime[$(GetUptime)] < $MIN_UPTIME" 1>&2
   rm -f $EMAIL_BODY
   exit 0

# Si on a une carte vidéo en erreur
# ou si le service est en défaut alors
elif [ "$FAILED_GPU" -o ! $(GetServiceStatus) = on ]; then
   [ "$DEBUG" = "TRUE" ] && echo "ethminer[$(GetServiceStatus)] != on" 1>&2
   [ "$DEBUG" = "TRUE" ] && echo "FAILED_GPU[$FAILED_GPU]" 1>&2

   # Retourner l'état "avant" du service dans le courriel
   echo                           >> $EMAIL_BODY
   sudo systemctl status $SERVICE >> $EMAIL_BODY
   
   [ $RESTART -lt $RESTART_MAX ] \
      && ServiceRestart \
      || SystemReboot

   # Si nous sommes ici alors on a tenté un SeviceRestart
   # Validons l'état actuel sinon reboot
   sleep 10
   [ ! $(GetServiceStatus) = on ] && SystemReboot

# Si ethminer est en "soft freeze"
# ref: https://github.com/ethereum-mining/ethminer/issues/1531
elif [ $(ProbeSoftFreeze) -eq 0 ]; then
   echo                                     >> $EMAIL_BODY
   echo "SOFT FREEZE TIMEOUT: $SOFTFREEZE"  >> $EMAIL_BODY

   # Retourner l'état "avant" du service dans le courriel
   echo                           >> $EMAIL_BODY
   sudo systemctl status $SERVICE >> $EMAIL_BODY

   [ $RESTART -lt $RESTART_MAX ] \
      && ServiceRestart \
      || SystemReboot

   # Si nous sommes ici alors on a tenté un SeviceRestart
   # Validons l'état actuel sinon reboot
   sleep 10
   [ ! $(GetServiceStatus) = on ] && SystemReboot
fi

rm -f $EMAIL_BODY

exit 0
