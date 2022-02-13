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
if (config.manual_list) {
    devices = require("./devices.json");
    console.log("[DCM] [listener.js] [" + getTime("log") + "] ", devices);
    console.log("[DCM] [listener.js] [" + getTime("log") + "] Total Devices: " + devices.length);
}
else if (config.use_ios_deploy) {
    cli_exec("ios-deploy -c","device_identification");
} else {
    cli_exec("cfgutil --format JSON list", "device_identification");
}

//------------------------------------------------------------------------------
//  PAYLOAD PROCESSING
//------------------------------------------------------------------------------
server.post("/", (payload, res) => {
    console.log("[DCM] [listener.js] [" + getTime("log") + "] Received a Payload:", payload.body);
    let target = payload.body;
    // GO THROUGH DEVICE ARRAY TO FIND A MATCH
    devices.forEach(async (device, i) => {
        switch (target.type) {

            // RESTART A DEVICE
            case "restart":
                if (device.name == target.device) {
                    let restart = await cli_exec(`idevicediagnostics${isWindows() ? ".exe" : ""} -u ${device.uuid} restart`, "device_command");

                    // THERE WAS AN ERROR WITH IDEVICEDIAGNOSTICS
                    if (restart.hasError) {
                        console.error("[DCM] [listener.js] [" + getTime("log") + "] Failed to Restart " + device.name + " : " + device.uuid + ".", restart.error);

                        // SEND ERROR TO DCM
                        res.json({
                            status: 'error',
                            node: config.name,
                            error: 'Failed to restart device.'
                        });
                    }
                    else {
                        // RESTART WAS SUCCESSFUL
                        console.log("[DCM] [listener.js] [" + getTime("log") + "] Restarted " + device.name + " : " + device.uuid + ".");

                        // SEND CONFIRMATION TO DCM
                        res.json({
                            status: 'ok'
                        });
                    }
                }
                break;

            // REOPEN THE GAME
            case "reopen":
                if (device.name == target.device) {
                    var ipaddr = '';
                    if (config.manual_ip) {
                        ipaddr = device.ipaddr;
                    }
                    else {
                        // Look for WiFi addresses since it's quick
                        ipaddr = await cli_exec("ping -t 1 " + device.name, 'device_ipaddr');
                        if (ipaddr == '') {
                            // Look for tethered addresses and blanks. This takes a while
                            ipaddr = await cli_exec("grep -A1 \"" + device.name.replace('+', '.*') + "\" /var/db/dhcpd_leases", 'device_ipaddr');
                        }
                    }
                    const reopen = await cli_exec("curl --connect-timeout 10 -m 10 http://" + ipaddr + ":8080/restart", "device_command");

                    // THERE WAS AN ERROR WITH CURL
                    if (reopen.hasError) {
                        console.error("[DCM] [listener.js] [" + getTime("log") + "] Failed to reopen game for " + device.name + " : " + device.uuid + ".");
                        if (reopen.error.toString().includes("Connection refused")) {
                            console.error("[DCM] [listener.js] [" + getTime("log") + "] The connection was refused to IP " + ipaddr + ".");
                        }
                        else if (reopen.error.toString().includes("Operation timed out")) {
                            console.error("[DCM] [listener.js] [" + getTime("log") + "] The connection timed out for IP " + ipaddr + ".");
                        }
                        else if (reopen.error.toString().includes("Connection reset by peer")) {
                            console.error("[DCM] [listener.js] [" + getTime("log") + "] The connection was disconnected for IP " + ipaddr + ".");
                        }
                        else {
                            console.error(reopen.error);
                        }

                        // SEND ERROR TO DCM
                        res.json({
                            status: 'error',
                            node: config.name,
                            error: 'Failed to reopen game.'
                        });
                    }
                    else {
                        // RESTART WAS SUCCESSFUL
                        console.log("[DCM] [listener.js] [" + getTime("log") + "] Reopened the game for " + device.name + " : " + device.uuid + ".");

                        // SEND CONFIRMATION TO DCM
                        res.json({
                            status: 'ok'
                        });
                    }
                }
                break;

            // REAPPLY THE SAM PROFILE
            case "profile":
                if (!config.use_ios_deploy && device.name == target.device) {
                    // REMOVE THE SAM PROFILE
                    var profile = await cli_exec("cfgutil -e " + device.ecid + " -K org.der -C org.crt remove-profile com.apple.configurator.singleappmode", "device_command");
                    if (profile.hasError) {
                        console.error("[DCM] [listener.js] [" + getTime("log") + "] Failed to remove the SAM1 profile from " + device.name + " : " + device.uuid + ".", profile.error);
                        res.json({
                            status: 'error',
                            node: config.name,
                            error: 'Failed to remove the SAM1 profile.'
                        });
                    }

                    // APPLY THE CLOCK PROFILE TO FORCE THE GAME CLOSED
                    profile = await cli_exec("cfgutil -e " + device.ecid + " -K org.der -C org.crt install-profile sam_clock.mobileconfig", "device_command");
                    if (profile.hasError) {
                        console.error("[DCM] [listener.js] [" + getTime("log") + "] Failed to add the SAM_CLOCK profile to " + device.name + " : " + device.uuid + ".", profile.error);
                        res.json({
                            status: 'error',
                            node: config.name,
                            error: 'Failed to add the SAM_CLOCK profile.'
                        });
                    }

                    // REMOVE THE SAM PROFILE AGAIN
                    profile = await cli_exec("cfgutil -e " + device.ecid + " -K org.der -C org.crt remove-profile com.apple.configurator.singleappmode", "device_command");
                    if (profile.hasError) {
                        console.error("[DCM] [listener.js] [" + getTime("log") + "] Failed to remove the SAM2 profile from " + device.name + " : " + device.uuid + ".", profile.error);
                        res.json({
                            status: 'error',
                            node: config.name,
                            error: 'Failed to remove the SAM2 profile.'
                        });
                    }

                    // APPLY THE POGO PROFILE TO RELAUNCH THE GAME
                    profile = await cli_exec("cfgutil -e " + device.ecid + " -K org.der -C org.crt install-profile sam_pogo.mobileconfig", "device_command");
                    if (profile.hasError) {
                        console.error("[DCM] [listener.js] [" + getTime("log") + "] Failed to add the SAM_CALC profile to " + device.name + " : " + device.uuid + ".", profile.error);
                        res.json({
                            status: 'error',
                            node: config.name,
                            error: 'Failed to add the SAM_POGO profile.'
                        });
                        break;
                    }

                    // REAPPLICATION WAS SUCCESSFUL
                    console.log("[DCM] [listener.js] [" + getTime("log") + "] Reapplied the SAM profile to " + device.name + " : " + device.uuid + ".");
                    // SEND CONFIRMATION TO DCM
                    res.json({
                        status: 'ok'
                    });
                }
                break;

            // CHANGE DEVICE BRIGHTNESS
            case "brightness":
                if (device.name == target.device) {
                    let ipaddr = '';
                    if (config.manual_ip) {
                        ipaddr = device.ipaddr;
                    }
                    else {
                        // Look for WiFi addresses since it's quick
                        ipaddr = await cli_exec("ping -t 1 " + device.name, 'device_ipaddr');
                        if (!ipaddr) {
                            // Look for tethered addresses and blanks. This takes a while
                            ipaddr = await cli_exec("grep -A1 \"" + device.name.replace('+', '.*') + "\" /var/db/dhcpd_leases", 'device_ipaddr');
                        }
                    }
                    const brightness = await cli_exec("curl --connect-timeout 10 -m 10 -X POST http://" + ipaddr + ":8080/brightness?value=" + target.value, "device_command");

                    // THERE WAS AN ERROR WITH CURL
                    if (brightness.hasError) {
                        console.error("[DCM] [listener.js] [" + getTime("log") + "] Failed to change brightness for " + device.name + " : " + device.uuid + ".");
                        if (reopen.error.toString().includes("Connection refused")) {
                            console.error("[DCM] [listener.js] [" + getTime("log") + "] The connection was refused to IP " + ipaddr + ".");
                        }
                        else if (reopen.error.toString().includes("Operation timed out")) {
                            console.error("[DCM] [listener.js] [" + getTime("log") + "] The connection timed out for IP " + ipaddr + ".");
                        }
                        else if (reopen.error.toString().includes("Connection reset by peer")) {
                            console.error("[DCM] [listener.js] [" + getTime("log") + "] The connection was disconnected for IP " + ipaddr + ".");
                        }
                        else {
                            console.error(reopen.error);
                        }

                        // SEND ERROR TO DCM
                        res.json({
                            status: 'error',
                            node: config.name,
                            error: 'Failed to change device brightness.'
                        });

                        // CHANGE WAS SUCCESSFUL
                    }
                    else {
                        console.log("[DCM] [listener.js] [" + getTime("log") + "] Device brightness was changed to " + target.value + "% for " + device.name + " : " + device.uuid + ".");

                        // SEND CONFIRMATION TO DCM
                        res.json({
                            status: 'ok'
                        });
                    }
                }
                break;
        }
    });
});

//------------------------------------------------------------------------------
//  COMMAND LINE EXECUTION
//------------------------------------------------------------------------------
function cli_exec(command, type) {
    return new Promise(async function(resolve) {
        let response = {};
        exec(command, async (err, stdout, stderr) => {
            if (err && !command.includes('ping')) {
                //console.error("[DCM] [listener.js] ["+getTime("log")+"]", err);
                response.hasError = true;
                response.error = err;
                return resolve(response);
            }
            else {
                switch (type) {

                    // INITIAL DEVICE IDENTIFICATION FOR DEVICE ARRAY
                    case 'device_identification':
                        if (config.use_ios_deploy) {
                            let data = stdout.split("\n");
                            var forloop = new Promise(async function(resolve, reject) {
                                var counter = 0;
                                await data.forEach(async (device,i) => {
                                    if (device.match(/iPhone|iPad|iPod/g) && !devices.some(d => d.uuid === device.split(' ')[2])) {
                                        let device_object = {};
                                        device_object.name = device.split("'")[1];
                                        device_object.uuid = device.split(" ")[2];
                                        devices.push(device_object);
                                        console.log("[DCM] [listener.js] [" + getTime("log") + "] Found Device:", device_object);
                                    }
                                    if (counter >= Object.keys(data).length - 1) {
                                        resolve();
                                    }
                                    else {
                                        counter++;
                                    }
                                });
                            });
                        } else {
                            let data = stdout.split("\n");
                            let json = JSON.parse(data[0]);
                            data = json.Output;
                            var forloop = new Promise(async function(resolve, reject) {
                                var counter = 0;
                                await Object.keys(data).forEach(async (device) => {
                                    if (data[device].deviceType.match(/iPhone|iPad|iPod/g)) {
                                        let device_object = {};
                                        device_object.name = data[device].name;
                                        device_object.uuid = data[device].UDID;
                                        device_object.ecid = data[device].ECID;
                                        devices.push(device_object);
                                        console.log("[DCM] [listener.js] [" + getTime("log") + "] Found Device:", device_object);
                                    }
                                    if (counter >= Object.keys(data).length - 1) {
                                        resolve();
                                    }
                                    else {
                                        counter++;
                                    }
                                });
                            });
                        }

                        forloop.then(() => {
                            console.log("[DCM] [listener.js] [" + getTime("log") + "] Total Devices: " + devices.length);
                            return resolve();
                        });
                        break;

                    // GET IP INFO
                    case 'device_ipaddr':
                        let ipaddr = '';
                        if (!err && command.includes('ping')) {
                            let ping_data = stdout.split("\n");
                            let string_data1 = ping_data[0].split("(");
                            let string_data2 = string_data1[1].split(")");
                            ipaddr = string_data2[0];
                        }
                        else if (!err) {
                            let ip_line = '';
                            let log_data = stdout.split("\n");
                            for (var line of log_data) {
                                if (line.includes("ip_address")) {
                                    ip_line = line;
                                    break;
                                }
                            }
                            let ip_strings = ip_line.split("=");
                            for (var line of ip_strings) {
                                if (line.includes("192.168.")) {
                                    ipaddr = line;
                                    break;
                                }
                            }
                            if (ipaddr == '') {
                                // Rarely, it may still be blank, check the log again
                                ipaddr = await cli_exec(command, 'device_ipaddr');
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
function getTime(type, unix) {
    if (!unix) {
        switch (type) {
            case "log":
                return Moment().format("hh:mmA");
            case "24hour":
                return Moment().format("HH:mm");
            case "full":
                return Moment().format("hh:mmA DD-MMM");
        }
    }
    else {
        switch (type) {
            case "24hour":
                return Moment.unix(unix).format("HH:mm");
            case "log":
                return Moment.unix(unix).format("hh:mmA");
            case "full":
                return Moment.unix(unix).format("hh:mmA DD-MMM");
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
console.info("[DCM] [listener.js] [" + getTime("log") + "] Now Listening on port " + config.port + ".");
