"""One StudioMCP tool call to an EXPLICIT Studio window (by studio id), saving any returned image.
Use it when several Studio windows are open: studio_mcp.py --place picks by name, and names can be stale
while a place is in Play mode (2026-11-06 a Lobby play session answered for the match place).

Usage (always run Python isolated):
  python3 -I tools/studio/studio_raw.py list                                   # ids and place names
  python3 -I tools/studio/studio_raw.py <studio_id> <tool> <args.json> [image_out]
args.json holds the tool arguments without studio_id. Check which place a window holds with
execute_luau {"datamodel_type":"Edit","code":"return game.PlaceId"} before changing anything.
"""
import json,subprocess,sys,time,select
if sys.argv[1] == "list":
    sid, tool, path = None, "list_roblox_studios", None
else:
    sid,tool,path=sys.argv[1:4]
args = json.load(open(path)) if path else {}
if sid: args["studio_id"] = sid
p=subprocess.Popen(["/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP"],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True,bufsize=1)
def req(i,m,pr,wait=100):
    p.stdin.write(json.dumps({"jsonrpc":"2.0","id":i,"method":m,"params":pr})+"\n");p.stdin.flush()
    end=time.time()+wait
    while time.time()<end:
        r,_,_=select.select([p.stdout],[],[],1)
        if r:
            d=json.loads(p.stdout.readline())
            if d.get("id")==i: return d
    return {"error":"timeout"}
req(1,"initialize",{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"x","version":"1"}})
p.stdin.write(json.dumps({"jsonrpc":"2.0","method":"notifications/initialized"})+"\n");p.stdin.flush()
time.sleep(3)
r=req(2,"tools/call",{"name":tool,"arguments":args})
import base64
saved=False
for c in (r.get("result") or {}).get("content", []):
    if c.get("type")=="image" and len(sys.argv)>4:
        open(sys.argv[4],"wb").write(base64.b64decode(c["data"])); print("saved",sys.argv[4]); saved=True
    elif c.get("type")=="text": print(c["text"][:6000])
if not r.get("result"): print(json.dumps(r)[:3000])
p.kill()
