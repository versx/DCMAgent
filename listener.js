//------------------------------------------------------------------------------
//  PACKAGE REQUIREMENTS
//------------------------------------------------------------------------------
const fs = require("fs");
const os = require("os");
const Moment = require("moment");
const Request = require("request");
const express = require("express");
const { exec } = require("child_process");
const config = require("./config.json");

// DEFINE THE EXPRESS SERVER
var server = express().use(express.json({ limit: "1mb" }));

// DEFINE RESPONSE HEADERS
server.use(function(req, res, next) {
  res.header("Access-Control-Allow-Origin", config.domain);
  res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
  next();
});

//------------------------------------------------------------------------------
//  GET LOCAL DEVICE INFORMATION
//------------------------------------------------------------------------------
var devices = [];
cli_exec("ios-deploy -c","device_identification");

//------------------------------------------------------------------------------
//  PAYLOAD PROCESSING
//------------------------------------------------------------------------------
server.post("/", (payload, res) => {
  console.log("[DCM] [listener.js] ["+getTime("log")+"] Received a Payload:",payload.body)
  let target = payload.body;
  // GO THROUGH DEVICE ARRAY TO FIND A MATCH
  devices.forEach( async (device,i) => {
    switch(target.type){

      // RESTART A DEVICE
      case "restart":
        if(device.name == target.device){
          let restart = await cli_exec(`idevicediagnostics${isWindows() ? ".exe" : ""} -u ${device.uuid} restart`,"device_command");

          // THERE WAS AN ERROR WITH IDEVICEDIAGNOSTICS
          if(restart.hasError){
            console.error("[DCM] [listener.js] ["+getTime("log")+"] Failed to Restart "+device.name+" : "+device.uuid+".",response.error);

            // SEND ERROR TO DCM
            res.json({ status: 'error', node: config.name, error:'Failed to restart device.' });

          // RESTART WAS SUCCESSFUL
          } else {
            console.log("[DCM] [listener.js] ["+getTime("log")+"] Restarted "+device.name+" : "+device.uuid+".");

            // SEND CONFIRMATION TO DCM
            res.json({ status: 'ok' });
          }
        }
        break;

      // REOPEN THE GAME
      case "reopen":
        if(device.name == target.device){
          let reopen = await cli_exec("curl http://"+device.ipaddr+":8080/restart","device_command");

          // THERE WAS AN ERROR WITH CURL
          if(reopen.hasError){
            console.error("[DCM] [listener.js] ["+getTime("log")+"] Failed to reopen game for "+device.name+" : "+device.uuid+".",response.error);

            // SEND ERROR TO DCM
            res.json({ status: 'error', node: config.name, error:'Failed to reopen game.' });

          // RESTART WAS SUCCESSFUL
          } else {
            console.log("[DCM] [listener.js] ["+getTime("log")+"] Reopened the game for "+device.name+" : "+device.uuid+".");

            // SEND CONFIRMATION TO DCM
            res.json({ status: 'ok' });
          }
        }
        break;
    }
  }); return;
});

//------------------------------------------------------------------------------
//  COMMAND LINE EXECUTION
//------------------------------------------------------------------------------
function cli_exec(command,type){
  return new Promise( async function(resolve){
    let response = {};
    exec(command, async (err, stdout, stderr) => {
      if(err && !command.includes('ping')){
        console.error("[DCM] [listener.js] ["+getTime("log")+"]", err);
        response.hasError = true;
        response.error = stderr;
      } else {
        switch(type){

          // INITIAL DEVICE IDENTIFICATION FOR DEVICE ARRAY
          case 'device_identification':
            let data = stdout.split("\n");
            var forloop = new Promise( async function(resolve, reject){
              var counter = 0;
              await data.forEach(async (device,i) => {
                if(device.includes('iPhone') || device.includes('iPad')){
                  let device_object = {};
                  device_object.name = device.split("'")[1];
                  device_object.uuid = device.split(" ")[2];
                  // Look for WiFi addresses since it's quick
                  device_object.ipaddr = await cli_exec("ping -t 1 "+device_object.name,'device_ipaddr');
                  if(device_object.ipaddr == ''){
                    // Look for tethered addresses and blanks. This takes a while
                    device_object.ipaddr = await cli_exec("idevicesyslog -u "+device_object.uuid+" -m '192.168.' -T 'IPv4'",'device_ipaddr');
                  }
                  devices.push(device_object);
                  console.log("[DCM] [listener.js] ["+getTime("log")+"] Found Device:", device_object);
                }
                if(counter >= data.length -1){
                  resolve();
                } else {
                  counter++
                }
              });
            });

            forloop.then(() => {
              console.log("[DCM] [listener.js] ["+getTime("log")+"] Total Devices: "+devices.length)
              return resolve();
            });
            break;

          // GET IP INFO
          case 'device_ipaddr':
            let ipaddr = '';
            if(!err && command.includes('ping')){
              let ping_data = stdout.split("\n");
              let string_data1 = ping_data[0].split("(");
              let string_data2 = string_data1[1].split(")");
              ipaddr = string_data2[0];
            }
            else if(!err) {
              let ip_line = '';
              let log_data = stdout.split("\n");
              for(var line of log_data){
                if(line.includes("<->IPv4")){
                  ip_line = line;
                  break;
                }
              }
              let ip_strings = ip_line.split(/ |:/);
              for(var line of ip_strings){
                if(line.includes("192.168.")){
                  ipaddr = line;
                  break;
                }
              }
            }
            return resolve(ipaddr);

          // GENERAL IDEVICEDIAGNOSTICS COMMAND
          case 'device_command':
            response.hasError = false;
            response.result = stdout;
            return resolve(response);
        }
      }
    });
  });
}

//------------------------------------------------------------------------------
//  GET TIME FUNCTION
//------------------------------------------------------------------------------
function getTime(type,unix){
  if(!unix){
    switch(type){
      case "log": return Moment().format("hh:mmA");
      case "24hour": return Moment().format("HH:mm");
      case "full": return Moment().format("hh:mmA DD-MMM");
    }
  } else{
    switch(type){
      case "24hour": return Moment.unix(unix).format("HH:mm");
      case "log": return Moment.unix(unix).format("hh:mmA");
      case "full": return Moment.unix(unix).format("hh:mmA DD-MMM");
    }
  }
}

//------------------------------------------------------------------------------
//  GET OS PLATFORM FUNCTION
//------------------------------------------------------------------------------
function isWindows() {
  return os.platform() === "win32";
}

// LISTEN TO THE SPECIFIED PORT FOR TRAFFIC
server.listen(config.port);
console.info("[DCM] [listener.js] ["+getTime("log")+"] Now Listening on port "+config.port+".");
