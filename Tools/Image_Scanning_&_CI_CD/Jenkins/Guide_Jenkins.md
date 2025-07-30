[Torna a README](../../../README.md)

## Deploy Jenkins

Andiamo per prima cosa ad implementare il namespace relativo, per poi deployare tutto il resto. Alla struttura classica ho aggiunto un init container per poter cambiare i permessi alla directory di base di jenkins `/var/jenkins_home` e dargli permessi per l'user jenkins. Eseguendo i successivi comandi avremo Jenkins già ben deployato.

```
kubectl apply -f jenkins-ns.yml

kubectl apply -f jenkins-setup.yml
```

Questo, però, non basta. Andando ad adoperare Jenkins per molto tempo, mi sono reso conto che jenkins rimuove costantemente (per sicurezza) la directory interna come safe directory per git. Occorre quindi adoperare un Cronjob + Bash per andare a settare ogni tot di tempo la directory come safe. Di seguito vi è l'istruzione bash.

```
#!/bin/bash

kubectl exec deploy/jenkins -n jenkins -- bash -c "cd /var/jenkins_home && git config --system --add safe.directory '*'";
```
>Contenuto Crontab da eseguire ogni TOT con un Cron

A questo punto vanno inizializzati i nodi di Jenkins per poter eseguire i processi delle pipeline ed è fatta.

---

