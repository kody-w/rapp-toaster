---
name: "hacker-news"
description: "Fetches the current top stories from Hacker News. Returns title, URL, score, and author for each. Use when the user asks what's on Hacker News, what's trending in tech, or for news headlines."
metadata: {"author": "RAPP", "tags": ["starter", "news", "http"]}
---

Fetches the current top stories from Hacker News. Returns title, URL, score, and author for each. Use when the user asks what's on Hacker News, what's trending in tech, or for news headlines.

<!-- toaster:generated:begin -->

## Parameters

The typed contract this capability answers to (JSON Schema — the deterministic layer):

```json
{
  "properties": {
    "count": {
      "description": "How many top stories to return. Default 10, max 30.",
      "maximum": 30,
      "minimum": 1,
      "type": "integer"
    }
  },
  "required": [],
  "type": "object"
}
```

<!-- toaster:generated:end -->

<!-- toaster:generated:begin -->

## Run this — do not improvise

This capability's deterministic implementation is a RAPP single-file agent, linked beside this file as `hacker_news_agent.py` and embedded as the fenced Python below (sha256 06f77e04b8d06ee2…; a byte-exact copy is also vaulted in the capsule comment at the end of this file). On a host with sandbox execution, run the linked file directly — if it is missing, write the fence contents verbatim to `hacker_news_agent.py` first:

```bash
python3 hacker_news_agent.py '{"key": "value"}'      # arguments as one JSON object
echo '{"key": "value"}' | python3 hacker_news_agent.py   # or on stdin
python3 hacker_news_agent.py --tool                      # emit the JSON tool contract
```

Treat stdout as a tool result. If it reports missing or unresolved inputs, stop and collect them. If it returns `steps`, execute those steps in order exactly as returned; if it returns `instructions`, follow them with the supplied inputs. Otherwise use the result verbatim. Do not invent behavior beyond that output. On a host without code execution, treat the Parameters schema and the code below as the exact specification and never paraphrase a step. Never edit inside the generated markers; a converter-equipped host can instead restore the original file checksum-verified with the installed `rapp-agent-converter/scripts/toast.py convert SKILL.md --to agent`.

```python  # rapp:deterministic
import sys
"""
hacker_news_agent.py — top stories from Hacker News, via the public Firebase API.

Mirrors the OG local brainstem's hacker_news_agent.py. No API key, no auth.
In Pyodide we fall back to fetch() via JS interop because urllib/requests
need the browser networking layer.
"""

import json
try:
    from agents.basic_agent import BasicAgent
except ImportError:  # running OUTSIDE the brainstem -- stay executable anyway.
    class BasicAgent:
        def __init__(self, name=None, metadata=None):
            if name:
                self.name = name
            if metadata:
                self.metadata = metadata

        def perform(self, **kwargs):
            return "Not implemented."

        def system_context(self):
            return None

        def to_tool(self):
            return {"type": "function", "function": {
                "name": self.name,
                "description": self.metadata.get("description", ""),
                "parameters": self.metadata.get("parameters", {})}}
__manifest__ = {
    "schema": "rapp-agent/1.0",
    "name": "@borg/hacker_news_agent",
    "version": "1.0.0",
    "display_name": "Hacker News",
    "description": "Fetches the top N stories from Hacker News.",
    "author": "RAPP",
    "tags": ["starter", "news", "http"],
    "category": "integrations",
    "quality_tier": "official",
    "requires_env": [],
    # Quick-click prompt the brainstem uses when you tap this agent's card/pill.
    "example_call": "What are the top 5 stories on Hacker News right now?",
}


_HN_TOP = "https://hacker-news.firebaseio.com/v0/topstories.json"
_HN_ITEM = "https://hacker-news.firebaseio.com/v0/item/{}.json"


def _fetch_json(url):
    """GET a URL → dict. Tries Pyodide JS fetch first, falls back to urllib."""
    try:
        from pyodide.http import open_url  # type: ignore
        return json.loads(open_url(url).read())
    except Exception:
        pass
    try:
        import urllib.request
        with urllib.request.urlopen(url, timeout=10) as r:
            return json.loads(r.read().decode("utf-8"))
    except Exception as e:
        raise RuntimeError(f"fetch failed: {e}")


class HackerNewsAgent(BasicAgent):
    def __init__(self):
        self.name = "HackerNews"
        self.metadata = {
            "name": self.name,
            "description": (
                "Fetches the current top stories from Hacker News. Returns title, "
                "URL, score, and author for each. Use when the user asks what's "
                "on Hacker News, what's trending in tech, or for news headlines."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "count": {
                        "type": "integer",
                        "description": "How many top stories to return. Default 10, max 30.",
                        "minimum": 1,
                        "maximum": 30,
                    },
                },
                "required": [],
            },
        }
        super().__init__(name=self.name, metadata=self.metadata)

    def perform(self, **kwargs):
        try:
            count = max(1, min(30, int(kwargs.get("count", 10) or 10)))
        except (TypeError, ValueError):
            return json.dumps({
                "status": "error",
                "message": "count must be an integer from 1 to 30",
            })

        try:
            top_ids = _fetch_json(_HN_TOP)
            if not isinstance(top_ids, list):
                raise RuntimeError("top stories response was not a list")
            top_ids = top_ids[:count]
        except Exception as e:
            return json.dumps({"status": "error", "message": str(e)})

        stories = []
        for sid in top_ids:
            try:
                d = _fetch_json(_HN_ITEM.format(sid))
                if not d:
                    continue
                stories.append({
                    "id": sid,
                    "title": d.get("title"),
                    "url": d.get("url") or f"https://news.ycombinator.com/item?id={sid}",
                    "score": d.get("score"),
                    "author": d.get("by"),
                    "comments": d.get("descendants", 0),
                })
            except Exception:
                continue

        # Markdown with proper [title](url) links + HN comments link.
        # The LLM tends to copy this format verbatim; pre-linked here means
        # the rendered chat bubble has clickable titles + comment threads.
        summary_lines = []
        for i, s in enumerate(stories):
            comments_url = f"https://news.ycombinator.com/item?id={s['id']}"
            summary_lines.append(
                f"{i+1}. **[{s['title']}]({s['url']})** "
                f"— {s.get('score', 0)} points, by {s.get('author', '?')} "
                f"· [{s.get('comments', 0)} comments]({comments_url})"
            )
        return json.dumps({
            "status": "success",
            "stories": stories,
            "summary": "Top Hacker News stories:\n\n" + "\n\n".join(summary_lines)
                       + "\n\nWhen presenting these to the user, render the titles as clickable markdown links exactly as written above.",
            "data_slush": {"count": len(stories), "top_url": stories[0]["url"] if stories else None},
        })


if __name__ == "__main__":
    # Standalone entry point -- no brainstem, no framework, no install.
    #     python3 hacker_news_agent.py '{"arg": "value"}'
    #     echo '{"arg": "value"}' | python3 hacker_news_agent.py
    #     python3 hacker_news_agent.py --tool
    _a = sys.argv[1:]
    if _a and _a[0] == "--tool":
        print(json.dumps(HackerNewsAgent().to_tool(), indent=2))
    else:
        _raw = _a[0] if _a else (sys.stdin.read().strip() or "{}")
        print(HackerNewsAgent().perform(**json.loads(_raw)))

# rci-capsule:v1:H4sIAAAAAAAC/+1aaXObzJb+K5Tuh9ivFAECCeSpzB3taEdoV5xyNdAIJDbRgIRS/u+3GyRbju3cO/POx6CkwnL69OmzPqc7P3MgCk0vyD24kW0XcjpEWmD5oeW5uYdcG4aaCREVmpDSoiCAbkiFnk+h0Ass/N4IPIeSgLaHATWCR1SkFBhGgYtHWKENC9RcGRQopHkBvgeuTmWTUQb+C4FmFqk5gtTRhG46RYQwH4D2CL8C4RdEee4t98L1dYgF0S13S1l4HNTMAnXh6WIqyoRAty0XomKukIMn4Pg2RLmH7z8KOdNzoA+28LpaC3/LPfzMaTZAmCSXTUbmqm3xWvF4G7hb/MFPsNwufvZhgCdy8CsdGtTl6Q5B2yhQf/21P4Jgi+4fHl3qcoVBcvNELs2LsBa/UQ443bEFyrHcO44p4KWEd9nw4haGd4+5lO4xV6BY5p6sD/9zf//KCp406IfU3SzxYSsIvKBALYAdZff3v8wZpFahdshzi3rk+Oju51sCcj3mUAjCCD3mHvA9JHzw9B/RORAhrMWMMFuPE6GQUiE2MlkJ3GKTpc7BYn+hOOYdo2e8lN9pCXvZk6UjrKcngzjhE5H97kkaPc3G8v1bWsugXC+kLGS5eAWuBu8uowuUbaHwV2WkCgEWdjwFS245mcqwxm89O4DI91zinACl3EHK6zF3/5mcl7vvD6lCfryzVCv9B8cV9nAK/gcG+tAcb7WPwuAO3r/V5XUF36jvN0KQ6ECWnkZMJuivCn9nAnLpHxigO2sNi8TtQXiHWd7fvx92sYj+AccsBLDe3Qi+/3oRvgh8H4f4R16aeaClp8u39MJnFGkCIkT6JZ4uL+4/HREF9i19+phGnvGYM8PQRw80TRJMMdE8R7VcgGUt4lvaCqHzT0v/9hPL8/xhyFzCi+TB2ykuLz4XKUuXt0PU5Hf0WBoH5y10O4JkdKxLkL4uUMxHo59/seGvLvuBHV9t+PrtH9QQBHvdO7rU0QpNyg88nCGp76nqf9xhjd7jKHJxfs9T0oi6Spu+K96ymeFiMBgMcXJ3cWzhDKJ5foJLhIWozPGoGAYqwMH7X3gS+JUwgDrO/AGkHAhcdMuMVBZSMPBHndJwBaHUSFVtSJk4EDXb0vaAPKVCEskuYuFxAa4k6EYwFDkOCJKntLp8EGAWrnUkwqAbOTAAIby7+PP9uxqQrfwJqwTz+c8d7PsXS//yAzvZW35vBLsGz3ub4Xl+Wnn2uYhL1XfCLF0z5vfjjjxhYfD9/V9/Ub/yvwx+jEoMy1M/sxL1JXXfL8Slninfw2kfJ1w1efmcOS/+/uWfXzDFpzwZRhWo79dRV9Vc+F4fsYS3SsMO+wu7Gw/+t9XubWpFkabhlPoucAlVar0s06a370kyzWecZriA3OCV66CHRxwk+E8OOxcW+/JQ3GGV3b2x3P3HcY2v14FLApawzyNI4m9LvBtXKRwiVwBVuDh7+uLi1G8c3bnGaBaKGCFpoZ0QmmNghTjkKKB6MSx+oBAdhOAJ2REyyYJ/voCUB8qG7ouzkyJFiswloV5ef2d+fL9k1R+kQFzrFLSx/CPPhc830z3fY6yFvCjQMFbLPWY/10x1+0Ri5AkQgFbEWeHilL+DpQUqtkCqDz9SsR6othVAFeB5a3K3SDLY0CL1NQO64w5lexqwKRWjBIwooIMh50dTF7HYhAO1h0kBF7wU3WJ2XZeSE0+3dIweIGUAG7PCw4mR0lJ6d5/K05umUAnnSAycNIBtR2Ht2JZKB/AQQYTztetCnLOIUGrgHQk6dmF49II9sbwNEhgQ6S/aeXQxnPWCMHX8RzdVQioqKuK1WlomN3UhqpNXKcolIx/dpycHuJaBp316winpEjGkRpnQAZl/BzizfE250GzxFdM95lzgXNDg/6hesKXfaeuGFmduhEtKRo7ZvGGkW8jH63p6ZXhjxlu61zYlI7vtVIgrjD7vUW7YvNbXx5xSk+WbTyHYpoH/PU0WAbZThr7cTBAqS9nYl19GaDjhb71rLkhRMK4BWMJbwQ8RsK0weQoteJnXMwxLs4B9Q0Tsjz0UPUE3TmW4TvIPahLhMP6aBjMpr44fXtzj4qokBaCso0q8iAqBn5XN1ArYjzUQ6LRv2XbxOtmlQ3rCHm9nEi1JjQS4lF6VWX5R5tuGjAqsrRlizz/+M5X++eJKGUrHXvRa1zKP+JqWN+MSfZaXVreYofEkV+SXOm8uY0KQ5v+CCymT9M/nFxbkR7q0WwBLMMjDdenk12nNMLbHfSpJJGy1ROmWFhapWbrcaxjjUE15UHhSFBbSmEYvQZ1FbfEah+/RdOqCfsarSNZyDUIMj9wUAxCYghu5B8raugQTfljLbA/DkbvrmHQpRQJR7q4Q/DewzccN7keiXQS5LOGSeF4/pzDu7ccifiQykPkLFOmfvCj8RppUXEGC3/Q1mfjBReSiDjVPhwRoh8ZXEaPaTxbxa7v0QeuGYcTFPMCyoY4rE3xOOzXyS3t76pfO/u41/V3dIfWUJ8u1cAJMG/pb0EaeiyQppe74yuwWhaQ0DgwBqZKvKfS1el6T2guz9/X1bVq7+6j5/tt7Mh8Bscfc39yp+Zjp39y/eYfx3inMBwHWI07OKAMkH8hA4uqSadUd1MJP9jSyXiW8wL2fn3dYF8Dz81Os9mbOy2bIp13hJ+VM8o4Yp7nJG8viVJPFU5FqQgNEdkixTIFsJFEcU/w3UzjYs53IIezZ3xOC05WQYz6hfP6oh/xQrZdSpr8pYx8Neb5ts7AlcIZ4iUYSK99eo4a6Btm3NyH3sgvyZ2fuz87cn525Pztzf3bm/uzM/dmZ+7Mz92dn7v91Z+6RnIOihOw2PJFcA09hdp76XMiROh9EWrrrkXvI/dmwe79hRw6VLZz30cspNAG1bw6fyTnzS2NDzqdfm5P0tJqYlty8Paz/P/QMeKIL3M89YKh7bRJyD2wh7WEw1wtmzD1j617BfHaYfiHIuqoc/uzbIMwOx3+SJxIJQUyof+ZSC5AbtcITUXnUrWVXg+bZ1XkpaEm9kz+zw3lUg8rK88Bxsp306zWtTneiWG2w1kEeScGkwczl5XmgtHV3LDgnTzZrUimsiZNym03OFRntK9NDaXM0y6JxrHV7Xd1esLq+WK3YhTSfKRsr6iozUD5uVuPTZLxMNluWpuW1oQ28ekWYKqDTjvQaG8fTmbbvTPoztl9bJl1GAMm0vjq6Ta3SUlZmNZ9U1Fmz3F0L09MqGkhCRZqawNxuPGXOOu3qJpLWgelqYAQkhU1crzntslbpnMxQOyyFemL2THNWW7UXe0s1unI5svqbzYnfcALfY3Y202uuhsmpNRUqjH8I9sJwsA0SFmwSrY+MSXRen+ByduhPAmNatjuH+kKxdlOgKvWpYoGjqionEdn+iB46VfMMdjXxYGkn2DiPaJ4pxfmhbw/F4LicorIfnBMJcBasyYy1TJJTO2wtlNaaOav2KhZ2mFQCwTRUuhU6rwN1xEfd7XDArVsnLwiXvd48rPh2tVsqS2fonOw9mEaNcNdItLlUHfM8rtWu2RvltZkkL5f5+hAM5b7E0gYXbwx3Ya7z7tpYTrWhOSv3KzMlv+Kt5Xm3UianGjKH4/bIQaVjywadoTRW65wYKsuFPo61qTFVK7Ktte3enJ757r5WdzRWkeNO55g/cqJXXrV5zq43pKRl+qd4NTTjSd2bNBsJsg/mNljg4Dy0WaBGrdb2OFhrh4FibxasU2q5zEpf9LazVSMslcfQ1hq1oerIrF8qobDudxreSRvUS3U9XvbdEX/sjARYljSaM7tjo3FG7HzVFWaO1O9F0tZvVfqcUhVn02pXlus6UruWkLR1To9lN6k25rYUuztYl7meP5yUy4NyV4v5+Zxp7RdVtufld8KI07Z8H8pCviNztDjypyet7hp5IJXK87ld3oCGHrTCqqDbobhaLeyV1Eathcv6rE+7++1oU9rsJC6uMHPuIA2m5fG0rK9Hq25d73eqp0PHnYZzVSih/WHAIFC1Yi0/THb9ccsRZYmP9s1B/hSLO3nMlVR+ypos35b4wW6rgNIhiX3bDYOOyiXV4MQ29sLy0A45Y2aPJu1mR+eBPC5VGoh1euaUP+1sj5Pp6lkf9sojby/seWW7DhpyAHs6d26op3jobVpyt4FQAIebkd1uLC3eH3fEZncpK0x7nF/3wUzbJp3V1OwKJwXg+jBQdwvxvDGbnRIqT0d14DFrezoeSHYYCyutulvOmj6UzNFEbgdMbT/q921/53Q6NCuJSX68a86UYLqYm6JWsmb7XqkxmJhaf2IuJkg3h32Nbg/nybYsesceD+AILvN857gTj8vtwTWt4eKUAFj1GyNumufN/f5kovnRVIejRWMfNyaN+WJhrNbroLvCgq0bZnLqt+WDmJecVaMEOyVooLElHMNtozrjmVNfkgYrZRjUbKVX1qUO51gbu0sP1GC1HAmH9qImrbrVqcKcFXu+7hgiLIMGkuzqeF5uCs2k5JZ6ELFrdREBoSfmp3NfnNndeHOE7SrSjJ2QHJZiUgbNulSXDKF1sPylOdOX1cDy2nQ8RfXKMLahPREXg3Z1tOnmj2BWOm12DesE5X6ptdTtxrJLY0DMiIatiPo4qOwlMO1X9ImYH051LdjU2ryGfLE+VGbW3uDbTB1NZhzbgbLa2YuNqhLq7Fnzg3kSbCJVOrYcfVZdadHaKtdHUnfk7PTN9FxaboStyYITNwKL6bolNZessbX5/MrWh3QHh2kIWseuOtijwXxhl8Z+I8+wHc/tjaWN74zEeLZd1Nqnfatszn2APZNvnSdaU2+PJozd3B6PSkNvcaWTCuf+VNOaLZFb0OVh84x6+cV8dLYUS5QnTWYUuuv9qYOrf5U+gNZACNj1ZNJnYnnlsxykJb0pWJJQbh/FSjIdgkbbEu3t3jx5pmGtFowRhKPafKOvrCPWXDuU+FnrqLqVWinZLHCA8e5W23INv+tFp4G/8oezYziL9cpA5KPQi02uScsJ6x/soOfPtwJ9rJ1CedVnbSiXhzPnJLfasdMJB7Ieb8rJ+hyW6nl3kz9MvPGiee4t5+55rAx5ZSAO1yu/pa1G49bYPVWcZrPDrmKvJR93yRIelpU8cIPJqhkf6XirnNeHRmsRVhchD4/jqk2X1VFQT5SE42kDyWyzuqiswo4H96DiGGzTbteqZXHDKcEhrtYgHAoVvWerXcQ5o4lv1wXAu6vRAJt92vCF7SbPooXV1seOa5WFqME3jbgbo4Xb6FbdUEcjp8lH5sZxjbhkLLbMHq0HgenP1TXLeGKLrzVXm16eixhJiGKjXGmPSkZiDNB6NoQdZp2vKovTvm+Wq42EjvXTnm3PotKmRverdsWSnRHdb7rl4XLQZeSxPO4LNCevpkNelIfiWlZCb9RssUO4QPGCi8SWG2wq9Hg67q9Dg66282VBnPGT47JJT/f8aCIoveoW2Imul7xjSy8Fa8+q7bjDrtZvGIN9pUeXWCH2kDcX1rFr1qeit5JLlmG3FG+qJs3q3rX2njjd+wmw173xjj4nrf06RLt22Gnwy6CsqRgAjPoNLuKUUr/OmGG+PAgOCEXBZBnYh/N56HeVZN5aH4ChSXnecndi0uEWJWshb0fhBvW7g5lX1YDV1OrNIN840bF/pDl3OzGcYVOQvO4Crkq79qQieaVZYiRxCLvhrLWt1TBmNCzcVGSglZ5jkIfovacnR8vWDRjBgC6+AHEaBRpNjo2fXl9lZ9L0RwCdNBYmKJUrmDPH8prKiCqjayxbESBnaBWhWmUrjKGzgqiVed1QGYi/crrIaZVyRWUEtVwB5UqlxMBqilgxcI6xqC75bwTfc2TX4CGd6+GT2XE/E2Og/fD1v9Hesu0chrmBZmFp2CKTIwDY95CFoXVyxe645dq+NDrpweQnzVEhPVHOkPPlCDxjixk//wvQs4wthisAAA==
```

<!-- toaster:generated:end -->

<!-- rci-capsule:v1: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 -->
