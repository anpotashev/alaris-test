***Диспетчер***

**dispatcher_net.json:**
```
{
  "LocalPort":5050
  ,"Proto":"udp"
}
```
 - LocalPort - порт на котором "диспечер" принимает запросы
 - Proto - 'udp'. Присутсвует только для упрощения кода скрипта
 
**dispatcher_setting.json:**
```
{
  "MaxWaitTime":10
  ,"MaxRequestLive":60
  ,"PingDelay":15
}
```

***Клиент***

**client_net.json:**
```
{
  "PeerPort":5050
  ,"Proto":"udp"
  ,"PeerAddr":"127.0.0.1"
}
```
 - PeerPort - порт "диспетчера"
 - PeerAddr - адрес "диспечера"
 - Proto - 'udp'. Присутствует только для упрощения кода скрипта
 

**client_setting.json:**
```
{
  "MaxRequestLive":60
  , "Range":10
}
```
 - MaxRequestLive - максимально время ожидания ответа с результатами вычислений от "диспетчера"
 - Range - Вычислитель решает кв.уравнение с коефициентами 0..Range
 

***Вычислитель***

Может запускаться с параметром командной строки - переопределением порта, указанного в _calculator_new.json_: `perl calculator.pl 5555`

**calculator_net.json:**
```
{
  "LocalPort":5151
  ,"Proto":"udp"
}
```
 - LocalPort - порт на котором "вычислитель" принимает запросы
 - Proto - 'udp'. Присутсвует только для упрощения кода скрипта

**calculator_setting.json:**
```
{
        "MinCalcDelay":1
        ,"MaxCalcDelay":5
        ,"PingTimeout":15
        ,"NotWorkingMaxTimeout":10
        ,"NotWorkingProbability":0.1
}
```
 - MinCalcDelay - минимальное время расчета в секундах
 - MaxCalcDelay - максимальное время расчета в секундах
 - PingTimeout - интервал в секундах через которые "вычислитель" подтверждает свою активность "диспетчеру"
 - NotWorkingMaxTimeout - максимальное время неработоспособности "вычислителя" в секундах
 - NotWorkingProbability = 0..1 вероятность для вычислителя выйти из строя в следующую секунду

**dispatcher_net.json:**
```
{
  "PeerPort":5050
  ,"Proto":"udp"
  ,"PeerAddr":"127.0.0.1"
}
```
 - PeerPort - порт "диспетчера"
 - PeerAddr - адрес "диспечера"
 - Proto - 'udp'. Присутствует только для упрощения скрипта
 
 
![Screenshot](https://github.com/anpotashev/alaris-test/blob/master/screen.PNG)
