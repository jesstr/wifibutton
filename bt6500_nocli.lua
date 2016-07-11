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

local recv_state = 1
local prompt = "bt6500 ~]"


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
    end 
end


function shutdown(relay_state) 
    print("Relay state: ", relay_state)
    print("Connection closed")
    if relay_state == 1 then 
        --led_blink(2, 200)
        count = 2
        tmr.alarm(0, 250, 1, toggleLED)
    end
    if relay_state == 0 then 
        --led_blink(1, 200)
        count = 1
        tmr.alarm(0, 250, 1, toggleLED)
    end
    conn:send("exit\n")
    conn:close()
    tmr.alarm(3, 1000, 1, function ()
        node.dsleep(0)
        end)
end


function switch_output_cb(c, out)

    if recv_state == 1 then
        if string.find(c, prompt)~=nil then
            conn:send("cat /proc/outs/" .. out .. " > /proc/outs/" .. out .. "\n")
            recv_state = recv_state + 1
        end
    elseif recv_state == 2 then
        if string.find(c, prompt)~=nil then
            conn:send("cat /proc/outs/" .. out .. "\n")
            recv_state = recv_state + 1
        end
    elseif recv_state == 3 then
        if string.find(c, prompt)~=nil then
             if string.find(c, "1%[")~=nil  then
                relay_state = 1
                recv_state = recv_state + 1
                shutdown(relay_state) 
            end 
            if string.find(c, "0%[")~=nil then
                relay_state = 0
                recv_state = recv_state + 1
                shutdown(relay_state) 
            end
        end
    end
end


function login_cb(c)
    if string.find(c, "bt6500 login:")~=nil then
            conn:send("hidden\n")
    end 
    if string.find(c, "Password:")~=nil then
        conn:send("12345\n")
    end    
    if string.find(c, prompt)~=nil then
        print("Logged in")
        loggedin=1
        --gpio.write(pin, gpio.HIGH)
    end
end


function connect()
    print("Connecting..")
    conn=net.createConnection(net.TCP, 0)

    conn:on("connection", function(conn, c) 
        print("Connected")
        --gpio.write(pin, gpio.LOW)
        connected = 1
    end )
    
    conn:on("receive", function(conn, c) 
        print(c)
        
        if loggedin==0 then
            login_cb(c)
        end
        
            switch_output_cb(c, 6)
        
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
