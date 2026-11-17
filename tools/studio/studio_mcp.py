"""Talks to Roblox Studio through Studio's built-in MCP server (StudioMCP) without any MCP setup.

Usage (always run Python isolated):
  python3 -I tools/studio/studio_mcp.py studios                  # open Studios and their places
  python3 -I tools/studio/studio_mcp.py tools                    # tools StudioMCP offers
  python3 -I tools/studio/studio_mcp.py batch steps.json         # run steps against one place
  python3 -I tools/studio/studio_mcp.py luau script.luau         # run a Luau file in Edit mode

Target place: --place <text> picks the Studio whose name contains <text> (place name or id).
Default: the main match place, Sky Island "134681445336553". Examples: --place Lobby, --place 88119126857665 (Classic)

steps.json is a list of steps, run in order through one connection:
  {"label": "build", "tool": "execute_luau",
   "args": {"studio_id": "$STUDIO", "datamodel_type": "Edit", "code": "return 1"}}
  {"label": "shot", "tool": "screen_capture", "save": "shot.jpg",
   "args": {"studio_id": "$STUDIO", "capture_id": "Shot_1",
            "camera_position": [0, 305, -15], "look_at_position": [0, 302, 0]}}
  {"label": "run file", "luau": "docs/vfx/MyAura.build.luau"}     # shorthand for execute_luau (Edit;
                                                                   # "datamodel": "Client"/"Server" in Play)
  {"sleep": 2.5}                                                   # wait between steps (e.g. mid-animation shots)
  {"play": true}       # start Play AND mark every player NoProgress (no XP, coins or tutorial writes to the
                       # tester's real profile); always use this instead of a bare start_stop_play
"$STUDIO" is replaced with the target Studio's id. "save" writes a returned image to that file;
"max" limits how much text is printed (default 3000).

The Studio link drops now and then (and the id changes when a place is reopened), so every
call is retried with the id looked up again by name.
"""
import base64
import json
import subprocess
import sys
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
import time

def _find_studio_mcp():
    """StudioMCP binary: $STUDIO_MCP, else the macOS app, else the newest Roblox Studio version on Windows."""
    import glob, os
    if os.environ.get("STUDIO_MCP"):
        return os.environ["STUDIO_MCP"]
    if sys.platform != "win32":
        return "/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP"
    root = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "Versions")
    found = [p for p in glob.glob(os.path.join(root, "*", "StudioMCP.exe"))
             if os.path.exists(os.path.join(os.path.dirname(p), "RobloxStudioBeta.exe"))]
    found = found or glob.glob(os.path.join(root, "*", "StudioMCP.exe"))
    if not found:
        raise SystemExit("StudioMCP.exe not found; set STUDIO_MCP")
    return max(found, key=os.path.getmtime)


def _line_reader(stream):
    """Lines from a pipe through a thread (select() does not work on Windows pipes): read(timeout) -> line|None|''."""
    import queue, threading
    lines = queue.Queue()

    def pump():
        for line in iter(stream.readline, ""):
            lines.put(line)
        lines.put("")

    threading.Thread(target=pump, daemon=True).start()

    def read(timeout):
        try:
            return lines.get(timeout=timeout)
        except queue.Empty:
            return None

    return read


STUDIO_MCP = _find_studio_mcp()
DEFAULT_PLACE = "134681445336553"

args = sys.argv[1:]
place = DEFAULT_PLACE
if "--place" in args:
    i = args.index("--place")
    place = args[i + 1]
    del args[i : i + 2]
if not args:
    raise SystemExit(__doc__)

proc = subprocess.Popen([STUDIO_MCP], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, encoding="utf-8", errors="replace", bufsize=1)
read_line = _line_reader(proc.stdout)
next_id = [0]


def send(message):
    proc.stdin.write(json.dumps(message) + "\n")
    proc.stdin.flush()


def request(method, params=None, timeout=180):
    next_id[0] += 1
    rid = next_id[0]
    send({"jsonrpc": "2.0", "id": rid, "method": method, "params": params or {}})
    end = time.time() + timeout
    while time.time() < end:
        line = read_line(1)
        if line is not None:
            if not line:
                break
            try:
                message = json.loads(line)
            except ValueError:
                continue
            if message.get("id") == rid:
                return message
    raise SystemExit(f"StudioMCP did not answer {method} in {timeout}s")


def text_of(result):
    return "".join(c.get("text", "") for c in result.get("result", {}).get("content", []))


def studios():
    try:
        return json.loads(text_of(request("tools/call", {"name": "list_roblox_studios", "arguments": {}}))).get("studios", [])
    except ValueError:
        return []


def find_studio(wait=40):
    # Studios show up a moment after StudioMCP starts, and their name a moment later still.
    for _ in range(wait):
        for studio in studios():
            if (studio.get("name") and place in studio["name"]) or place == str(studio.get("placeId")):
                return studio["id"]
        time.sleep(1)
    return None


def call(name, arguments, studio_id):
    arguments = json.loads(json.dumps(arguments).replace("$STUDIO", studio_id or "missing"))
    for _ in range(8):
        result = request("tools/call", {"name": name, "arguments": arguments})
        text = text_of(result)
        if "not connected" not in text and "No Roblox Studio instances" not in text:
            return result
        time.sleep(2)
        studio_id = find_studio(wait=10) or studio_id
        if "studio_id" in arguments:
            arguments["studio_id"] = studio_id
    return result


def print_result(result, step):
    if "error" in result:
        print("ERROR", result["error"])
    for content in result.get("result", {}).get("content", []):
        if content.get("type") == "image" and step.get("save"):
            with open(step["save"], "wb") as file:
                file.write(base64.b64decode(content["data"]))
            print("saved", step["save"])
        else:
            print(content.get("text", "")[: step.get("max", 3000)])


# Runs on the Play server right after Play starts: every player (now and later) gets the server-only NoProgress
# attribute, which towerDamage (kill XP), MatchRewards (coins/gems/XP) and TutorialService honour.
GUARD = """
local Players = game:GetService("Players")
local function mark(p) p:SetAttribute("NoProgress", true) end
for _, p in Players:GetPlayers() do mark(p) end
Players.PlayerAdded:Connect(mark)
return "guarded " .. #Players:GetPlayers()
"""

request("initialize", {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "tower-tools", "version": "1"}})
send({"jsonrpc": "2.0", "method": "notifications/initialized"})

command = args[0]
if command == "studios":
    time.sleep(3)
    for studio in studios():
        print(studio["id"], studio.get("name"))
elif command == "tools":
    for tool in request("tools/list")["result"]["tools"]:
        print("==", tool["name"], "\n", tool.get("description", "")[:500])
else:
    studio_id = find_studio()
    if not studio_id:
        raise SystemExit(f'No open Studio whose name contains "{place}". Run "studios" to see what is open.')
    if command == "luau":
        steps = [{"label": args[1], "luau": args[1]}]
    elif command == "batch":
        with open(args[1], encoding="utf-8") as file:
            steps = json.load(file)
    else:
        raise SystemExit(__doc__)
    for step in steps:
        if "sleep" in step:
            time.sleep(step["sleep"])
            continue
        if step.get("play"):
            print("#### play (NoProgress guard)")
            print_result(call("start_stop_play", {"studio_id": "$STUDIO", "is_start": True}, studio_id), step)
            print_result(call("execute_luau", {"studio_id": "$STUDIO", "datamodel_type": "Server", "code": GUARD}, studio_id), step)
            continue
        if "luau" in step:
            with open(step["luau"], encoding="utf-8") as file:
                code = file.read()
            tool, arguments = "execute_luau", {"studio_id": "$STUDIO", "datamodel_type": step.get("datamodel", "Edit"), "code": code}
        else:
            tool, arguments = step["tool"], step["args"]
        print("####", step.get("label", tool))
        print_result(call(tool, arguments, studio_id), step)

proc.terminate()
