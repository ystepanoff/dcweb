var last_msg_id = 0;
var first_msg_id = 0;
var curr_cnt = 40;
var msg_ids = new Array();

var url_regexp = /(https?|ftp):\/\/(\S*)/i;
var image_url_regexp = /https?:\/\/\S*\.(jpe?g|png|gif|bmp)/i;
var magnet_regexp = /magnet:(\S*)&dn=(\S*)/i;

var user_color = {
    "mikroz": "#ff0000",
    "mikroz_": "#ff0000",
    "mahalex": "#842dce",
    "mahalex_": "#842dce",
    "Zen_F10": "#0000ff",
    "satter": "#ff00ff",
    "satter_": "#ff00ff",
    "газява": "#505050",
    "Alucard": "#0e8489",
    "Alucard_": "#0e8489",
    "jlarkolub": "#0e8489",
    "alvelain": "#808000",
    "alpha": "#348017",
    "beta": "#348017",
};

function req_object()
{
    return (window.XMLHttpRequest) ? new XMLHttpRequest() :
        (window.ActiveXObject) ? new ActiveXObject("Microsoft.XMLHTTP") : false;
}

function replace_specials(message)
{
    message = message.replace(/</g, "&lt;");
    message = message.replace(/>/g, "&gt;");
    message = message.replace(/\n/g, "&nbsp; <span style=\"color:#303030;\">//</span> &nbsp;");
    message = message.replace(/&nbsp;/g, " ");

    return message;
}

function add_nick(user)
{
    msg = document.getElementById('idMessage');
    if (msg.value)
        msg.value += user;
    else
        msg.value += user + ': ';
    msg.focus();
}

function set_user_style(user)
{
    b_node = document.createElement('b');
    span_node = document.createElement('span');
    b_node.appendChild(span_node);
    msg = document.getElementById('idMessage');

    span_node.setAttribute("onClick", "add_nick('" + user + "');");

    span_node.appendChild(document.createTextNode("<"));
    span_node.appendChild(document.createTextNode(user));
    span_node.appendChild(document.createTextNode(">"));

    if (typeof user_color[user] !== 'undefined')
    {
        span_node.setAttribute("style", "color:" + user_color[user] + ";");
        return b_node;
    }

    if (user === "fijiol")
    {
        b_node.setAttribute("onClick", "add_nick('fijiol');");
        b_node.innerHTML = "&lt;" +
                           "<span style=\"color:#ff0000;\">f</span>" +
                           "<span style=\"color:#ff7f00;\">i</span>" +
                           "<span style=\"color:#ffff00;\">j</span>" +
                           "<span style=\"color:#00ff00;\">i</span>" +
                           "<span style=\"color:#0000ff;\">o</span>" +
                           "<span style=\"color:#4b0082;\">l</span>" +
                           "&gt;";
    }

    if (user === "error")
    {
        b_node.setAttribute("onClick", "add_nick('error');");
        b_node.innerHTML = "&lt;" +
                           "<span style=\"color:#ff0000;\">e</span>" +
                           "<span style=\"color:#ff7f00;\">r</span>" +
                           "<span style=\"color:#ffff00;\">r</span>" +
                           "<span style=\"color:#00ff00;\">o</span>" +
                           "<span style=\"color:#0000ff;\">r</span>" +
                           "&gt;";
    }

    return b_node;
}

function parse_urls(message)
{
    var parts = message.split(" ");

    for (var i = 0; i < parts.length; i++)
    {
        if (image_url_regexp.test(parts[i]))
        {
            parts[i] = "<a href=\"" + parts[i] + "\" target=\"_blank\"><img src=\"" + parts[i] + "\" width=\"200\" /></a>";
        } else
        {
            if (url_regexp.test(parts[i]))
            {
                parts[i] = "<a href=\"" + parts[i] + "\" target=\"_blank\">" + decodeURIComponent(parts[i]) + "</a>";
            } else
            {
                if (magnet_regexp.test(parts[i]))
                {
                    parts[i] = parts[i].replace(magnet_regexp, "$2");
                    parts[i] = parts[i].replace(/\+/g, " ");
                    parts[i] = "<span style=\"color:#888888;\">[" + decodeURIComponent(parts[i]) + "]</span>";
                }
            }
        }
    }

    return parts.join(" ");
}

function create_message_row(msg)
{
    var msg_row = document.createElement('tr');
    msg_row.id = "msg-" + msg.id;

    var t_time = document.createElement('td');
    t_time.className = "time_column";

    var t_msg = document.createElement('td');
    t_msg.className = "msg_column";

    t_time.appendChild(document.createTextNode(msg.time));
    if (msg.status == "1")
    {
        t_msg.innerHTML = "<i>" + parse_urls(replace_specials(msg.message)) + "</i>";
    } else
    {
        t_msg.appendChild(set_user_style(msg.nick));
        t_msg.innerHTML += " " + parse_urls(replace_specials(msg.message));
    }

    msg_row.appendChild(t_time);
    msg_row.appendChild(t_msg);

    return msg_row;
}

function remove_message(id)
{
    var msgrow = document.getElementById('msg-' + id);
    msgrow.parentNode.removeChild(msgrow);
    msg_ids = msg_ids.slice(1);
}

function load_json_first(req)
{
    var data = JSON.parse(req.responseText);
    var messages = document.getElementById('messages');

    while (messages.hasChildNodes())
        messages.removeChild(messages.lastChild);

    var msgtab = document.createElement('table');
    messages.appendChild(msgtab);

    for (var i = 0; i < data.length; i++)
    {
        msg_ids.push(data[i].id);
        msgtab.appendChild(create_message_row(data[i]));
    }

    first_msg_id = data[0].id;
    last_msg_id = data[data.length-1].id;
}

function load_json(req)
{
    var data = JSON.parse(req.responseText);
    var msgtab = document.getElementById('msg-' + msg_ids[0]).parentNode;

    for (var i = 0; i < data.length; i++)
    {
        if (data[i].id > msg_ids[msg_ids.length-1])
        {
            if (msg_ids.length >= curr_cnt)
                remove_message(msg_ids[0]);
            msg_ids.push(data[i].id);
            msgtab.appendChild(create_message_row(data[i]));
        }
    }

    if (data.length > 0)
    {
        first_msg_id = msg_ids[0];
        last_msg_id = data[data.length-1].id;
    }
}

function load_json_history(req)
{
    var data = JSON.parse(req.responseText);
    var msgtab = document.getElementById('msg-' + first_msg_id).parentNode;
    
    for (var i = data.length-1; i >= 0; i--)
    {
        if (data[i].id < first_msg_id)
        {
            msgtab.insertBefore(create_message_row(data[i]), document.getElementById('msg-' + first_msg_id));
            msg_ids.unshift(data[i].id);
            first_msg_id = data[i].id;
        }
    }
}


function load_more()
{
    var req = req_object();
    var more_button = document.getElementById('more');

    more_button.innerHTML = '<img src="/preloader" alt="Loading..." />';

    req.onreadystatechange = function()
    {
        if (req.readyState == 4 && req.status == 200)
        {
            load_json_history(req);
            more_button.innerHTML = '<form><input type="button" value="Ещё!" class="more_button"  onClick="load_more();" /></form>';
        }
    }

    curr_cnt += 10;
    req.open("GET", "/messages?cnt=" + curr_cnt, true);
    req.send(null);
}

function get_last_messages()
{
    var req = req_object();

    req.onreadystatechange = function()
    {
        if (req.readyState == 4 && req.status == 200)
        {
            load_json(req);
            setTimeout('get_last_messages();', 2000);
        }
    }

    req.open("GET", "/from_id?id=" + last_msg_id, true);
    req.send(null);
}

function get_messages_first()
{
    var req = req_object();

    req.onreadystatechange = function()
    {
        if (req.readyState == 4 && req.status == 200)
        {
            load_json_first(req);
            setTimeout('window.scrollTo(0, document.body.scrollHeight);', 200);
            setTimeout('get_last_messages();', 2000);
        }
    }

    req.open("GET", "/messages", true);
    req.send(null);
}

function send_message(hash)
{
    var msg = document.getElementById('idMessage');
    var message = msg.value;
    msg.value = "";

    var req = req_object();

    req.open("POST", "/send", true);
    req.onreadystatechange = function()
    {
        if (req.readyState == 4 && req.status == 200)
        {
        }
    }

    req.setRequestHeader('Content-type', 'application/x-www-form-urlencoded');
    req.setRequestHeader("Connection", "close");

    req.send("hash=" + encodeURIComponent(hash) + "&message=" + encodeURIComponent(message));

    return false;
}

function init()
{
    get_messages_first();
}
