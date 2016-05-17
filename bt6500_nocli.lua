local pin = 4            --> GPIO2
local value = gpio.HIGH
local duration = 100    --> 1 second
local count = 1
local n = 0

local loggedin = 0
local i = 1
local relay_state = 0
local state = 0
local attempt = 5
local connected = 0

cmds = {
    "relay R3 info\n",
    "relay R3 on\n",
    "relay R3 info\n",
    "relay R3 off\n"
}


gpio.mode(pin, gpio.OUTPUT)
gpio.write(pin, value)

function led_blink(cnt, dur)
    count = cnt
    tmr.alarm(0, dur, 1, toggleLED)
end

-- Function toggles LED state
function toggleLED ()
    if value == gpio.LOW then
        value = gpio.HIGH
        n = n + 1
    else
        value = gpio.LOW
        
    end

    gpio.write(pin, value)

    if n == count then
        tmr.stop(0)
--        node.dsleep(0)
    end 
end



function shutdown(relay_state) 
    print("Relay state: ", relay_state)
    print("Connection closed")
    if relay_state == 1 then 
        --led_blink(2, 200)
        count = 2
        tmr.alarm(0, 200, 1, toggleLED)
    end
    if relay_state == 0 then 
        --led_blink(1, 200)
        count = 1
        tmr.alarm(0, 200, 1, toggleLED)
    end
    conn:send("exit\n")
    conn:close()
end

--echo 1 > /proc/outs/7

function set_relay_cb(c, relay, state)
    if string.find(c, "Switch relay")~=nil then
        conn:send("relay " .. relay .. " info\n")
    end
    if string.find(c, "bt6500#")~=nil then
        conn:send("relay " .. relay .. " " .. state .. "\n")
    end
    if string.find(c, "service relay, Opened")~=nil then
        relay_state = 1
        shutdown(relay_state) 
    end
    if string.find(c, "service relay, Closed")~=nil then
        relay_state = 0
        shutdown(relay_state) 
    end
end

function switch_relay_cb(c, relay)
    if string.find(c, "Switch relay")~=nil then
        conn:send("relay " .. relay .. " info\n")
    end
    if string.find(c, "service relay, Opened")~=nil then
        relay_state = 1
        conn:send("relay " .. relay .. " off\n")
        if state == 1 then
            shutdown(relay_state) 
        end
        state = 1    
    end
    if string.find(c, "service relay, Closed")~=nil then
        relay_state = 0
        conn:send("relay " .. relay .. " on\n")
        if state == 1 then
            shutdown(relay_state) 
        end
        state = 1
    end
     if string.find(c, "bt6500#")~=nil then
        conn:send("relay " .. relay .. " info\n")
    end
end

function login_cb(c)
    if string.find(c, "bt6500 login:")~=nil then
            conn:send("admin\n")
    end 
    if string.find(c, "Password:")~=nil then
        conn:send("12345\n")
    end    
    if string.find(c, "bt6500#")~=nil then
        print("Logged in")
        loggedin=1
        gpio.write(pin, gpio.HIGH)
    end
end

function commands_cb(c)
    if cmds[i]==nil then   
        conn:close()
        print("Connection closed")
    end
    if string.find(c, "bt6500#")~=nil then
        conn:send(cmds[i])
        i=i+1
    end 

end

function connect()
    print("Connecting..")
    conn=net.createConnection(net.TCP, 0)

    conn:on("connection", function(conn, c) 
        print("Connected")
        --led_blink(1, 100)
        gpio.write(pin, gpio.LOW)
        connected = 1
    end )
    
    conn:on("receive", function(conn, c) 
        print(c)
        
        if loggedin==0 then
            login_cb(c)
        end

        --commands_cb(c);
        
        --set_relay_cb(c, "R3", "off")
        switch_relay_cb(c, "R1")
        
    end )
    
    conn:connect(23,"192.168.14.19")
    
end

tmr.alarm(1, 1000, 1, function()
  if connected == 0 then
  gpio.write(pin, gpio.LOW)
  print("Connecting..")
  gpio.write(pin, gpio.HIGH)
  attempt = attempt - 1
  if attempt == 0 then 
    tmr.stop(1)
    print("Telnet connection error.")
    dofile ("led.lua")
    end
 else
  tmr.stop(1)
 end
 end)

connect()
