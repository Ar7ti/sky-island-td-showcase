"""Calls ONE StudioMCP tool and waits long for its answer (studio_mcp.py gives up after 180 s).
For slow tools: generate_mesh (several minutes), upload_image, anything that builds or uploads.

Usage: python3 -I tools/studio/studio_call.py <place-text> <tool> <args.json> [timeout-seconds]
  place-text  part of the Studio's name, e.g. 134681445336553 (match place)
  args.json   the tool's arguments without studio_id (it is filled in)
Prints the raw JSON-RPC answer (first 3000 characters).

Known (2026-11-05): generate_avatar and auto_setup_avatar fail and can crash Studio - don't use them.
"""
import json,subprocess,select,time,sys
place, tool, args_path = sys.argv[1:4]
timeout = float(sys.argv[4]) if len(sys.argv) > 4 else 900
p=subprocess.Popen(["/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP"],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,bufsize=1)
def send(m): p.stdin.write(json.dumps(m)+"\n"); p.stdin.flush()
def req(i,method,params={},wait=60):
    send({"jsonrpc":"2.0","id":i,"method":method,"params":params})
    end=time.time()+wait
    while time.time()<end:
        r,_,_=select.select([p.stdout],[],[],1)
        if r:
            line=p.stdout.readline()
            try: msg=json.loads(line)
            except: continue
            if msg.get("id")==i: return msg
    return {"error":"timeout"}
req(1,"initialize",{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"x","version":"1"}})
send({"jsonrpc":"2.0","method":"notifications/initialized"})
sid=None
for attempt in range(15):
    time.sleep(3)
    studios=req(10+attempt,"tools/call",{"name":"list_roblox_studios","arguments":{}})
    text="".join(c.get("text","") for c in studios.get("result",{}).get("content",[]))
    for s in json.loads(text).get("studios", []):
        if place in str(s.get("name")): sid=s["id"]
    if sid: break
if not sid: raise SystemExit("studio not found: "+text[:300])
args=json.load(open(args_path)); args["studio_id"]=sid
r=req(3,"tools/call",{"name":tool,"arguments":args},wait=timeout)
print(json.dumps(r)[:3000])
p.terminate()
