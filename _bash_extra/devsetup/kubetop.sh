todate=$(date  "+%Y-%m-%d %H:%M:%S")
echo "Start of kubetop capture at $todate" > ~/bin/a.txt
sleep 10

while :
do
   echo "###################" >>  ~/bin/a.txt
   date "+%Y-%m-%d %H:%M:%S" >>  ~/bin/a.txt
   echo "Running pods" >>  ~/bin/a.txt
   kubectl get pods | grep -i bb-bot >>  ~/bin/a.txt
   echo "Pod health" >>  ~/bin/a.txt
   kubectl top pods | grep -i bb-bot >>  ~/bin/a.txt   
   echo "Sleep for 15 secs.." >>  ~/bin/a.txt
   sleep 15   
done 
 