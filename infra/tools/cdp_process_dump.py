#!/usr/bin/env python3
import asyncio
import json
import os
import sys
import urllib.request

import websockets


async def call(ws, method, params=None, session_id=None):
    call.counter += 1
    message = {"id": call.counter, "method": method, "params": params or {}}
    if session_id:
        message["sessionId"] = session_id
    await ws.send(json.dumps(message))
    while True:
        message = json.loads(await ws.recv())
        if message.get("id") == call.counter:
            return message


call.counter = 0


async def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: cdp_process_dump.py PORT OUT_DIR")

    port = sys.argv[1]
    out_dir = sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)

    with urllib.request.urlopen(f"http://127.0.0.1:{port}/json/version", timeout=5) as response:
        version = json.load(response)

    async with websockets.connect(version["webSocketDebuggerUrl"], max_size=20_000_000) as ws:
        for method, filename in (
            ("SystemInfo.getProcessInfo", "processInfo.json"),
            ("Target.getTargets", "targets.json"),
        ):
            try:
                data = await call(ws, method)
            except Exception as exc:
                data = {"error": repr(exc)}
            with open(f"{out_dir}/{filename}", "w", encoding="utf-8") as output:
                json.dump(data, output, indent=2)
            if method == "Target.getTargets":
                targets = data.get("result", {}).get("targetInfos", [])

        page_metrics = []
        for info in targets:
            if info.get("type") != "page":
                continue
            attached = await call(
                ws, "Target.attachToTarget", {"targetId": info["targetId"], "flatten": True}
            )
            session_id = attached.get("result", {}).get("sessionId")
            if not session_id:
                continue
            await call(ws, "Performance.enable", session_id=session_id)
            metrics = await call(ws, "Performance.getMetrics", session_id=session_id)
            metric_map = {
                metric["name"]: metric["value"]
                for metric in metrics.get("result", {}).get("metrics", [])
            }
            page_metrics.append(
                {
                    "title": info.get("title"),
                    "url": info.get("url"),
                    "TaskDuration": metric_map.get("TaskDuration", 0),
                    "ScriptDuration": metric_map.get("ScriptDuration", 0),
                    "LayoutDuration": metric_map.get("LayoutDuration", 0),
                    "RecalcStyleDuration": metric_map.get("RecalcStyleDuration", 0),
                    "JSHeapUsedSize": metric_map.get("JSHeapUsedSize", 0),
                }
            )
            await call(ws, "Target.detachFromTarget", {"sessionId": session_id})
        with open(f"{out_dir}/pageMetrics.json", "w", encoding="utf-8") as output:
            json.dump(page_metrics, output, indent=2)

        target = await call(ws, "Target.createTarget", {"url": "chrome://discards/"})
        target_id = target.get("result", {}).get("targetId")
        if target_id:
            attached = await call(
                ws, "Target.attachToTarget", {"targetId": target_id, "flatten": True}
            )
            session_id = attached.get("result", {}).get("sessionId")
            if session_id:
                await call(ws, "Runtime.enable", session_id=session_id)
                await asyncio.sleep(2)
                result = await call(
                    ws,
                    "Runtime.evaluate",
                    {
                        "expression": """
                            (function text(node) {
                              let out = '';
                              if (node.nodeType === Node.TEXT_NODE) {
                                out += node.textContent + '\\n';
                              }
                              if (node.shadowRoot) {
                                out += text(node.shadowRoot);
                              }
                              for (const child of node.childNodes) {
                                out += text(child);
                              }
                              return out;
                            })(document.body)
                        """,
                        "returnByValue": True,
                    },
                    session_id=session_id,
                )
                with open(f"{out_dir}/discards.txt", "w", encoding="utf-8") as output:
                    output.write(
                        result.get("result", {})
                        .get("result", {})
                        .get("value", "")
                    )


if __name__ == "__main__":
    asyncio.run(main())
