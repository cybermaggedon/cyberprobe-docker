|||
    --
    -- Cybermon configuration file, used to tailor the behaviour of cybermon.
    -- This one sends network events over a TCP socket
    --

    -- This file is a module, so you need to create a table, which will be
    -- returned to the calling environment.  It doesn't matter what you call it.
    local observer = {}

    -- Other modules -----------------------------------------------------------
    local json = require("json")
    local os = require("os")
    local model = require("util.json")
    local socket = require("socket")

    -- Config ------------------------------------------------------------------

    --
    -- We either bind to localhost:48879 or we can
    -- configure the socket we send data to with
    -- the environment variables.
    local host, port, tcp

    if os.getenv("SOCKET_HOST") then
      host = os.getenv("SOCKET_HOST")
    else
      host = "localhost"
    end

    if os.getenv("SOCKET_PORT") then
      port = tonumber(os.getenv("SOCKET_PORT"))
    else
      port = 48879
    end

    -- Initialise.
    local init = function()
      print("Connecting to: "..host..":"..port)
      tcp = assert(socket.tcp())

      while true do
        ret, err = tcp:connect(host, port)
        if ret or err == "already connected" then
          break
        else
          print("Socket connect failed: "..err)
          socket.select(nil, nil, 5)
        end
      end
      print("Connected to socket")
    end

    -- TCO object submission function - just pushes the object through the socker.
    local submit = function(obs)
      while true do
        -- note json.encode add a newline
        if tcp:send(json.encode(obs).."\n") then
          break
        else
          print("Socket delivery failed, will reconnect. (this means we've "..
                "potentially dropped the previous message)")
          tcp:close()
          init()
        end
      end
    end

    -- Call the JSON functions for all observer functions.
    observer.trigger_up = model.trigger_up
    observer.trigger_down = model.trigger_down
    observer.connection_up = model.connection_up
    observer.connection_down = model.connection_down
    observer.unrecognised_datagram = model.unrecognised_datagram
    observer.unrecognised_stream = model.unrecognised_stream
    observer.icmp = model.icmp
    observer.imap = model.imap
    observer.imap_ssl = model.imap_ssl
    observer.pop3 = model.pop3
    observer.pop3_ssl = model.pop3_ssl
    observer.http_request = model.http_request
    observer.http_response = model.http_response
    observer.sip_request = model.sip_request
    observer.sip_response = model.sip_response
    observer.sip_ssl = model.sip_ssl
    observer.smtp_command = model.smtp_command
    observer.smtp_response = model.smtp_response
    observer.smtp_data = model.smtp_data
    observer.dns_message = model.dns_message
    observer.ftp_command = model.ftp_command
    observer.ftp_response = model.ftp_response
    observer.ntp_timestamp_message = model.ntp_timestamp_message
    observer.ntp_control_message = model.ntp_control_message
    observer.ntp_private_message = model.ntp_private_message

    -- Register submission.
    model.init(submit)

    -- Initialise
    init()

    -- Return the table
    return observer
|||
