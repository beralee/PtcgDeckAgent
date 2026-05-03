#!/usr/bin/env python3
"""Generate the static community coach page data.

The page is intentionally narrow: one environment interpretation homework built
around a deck link that can be imported into the game. It favors high-signal
coaching over broad news aggregation.
"""

from __future__ import annotations

import argparse
import email.utils
import html
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any
from xml.etree import ElementTree


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CREATORS = ROOT / "tools" / "community" / "creators.json"
DEFAULT_OUTPUT = ROOT / "community" / "data" / "community-data.json"

OFFICIAL_RSS = "https://www.pokemon.cn/category/tcg/feed"
MIK_HOME_API = "https://tcg.mik.moe/api/v3/app/home"
MIK_SERIES_API = "https://tcg.mik.moe/api/v3/tournament/series-list"
MIK_TOURNAMENT_DETAIL_API = "https://tcg.mik.moe/api/v3/tournament/detail"
MIK_DECK_API = "https://tcg.mik.moe/api/v3/deck/deck-static-by-date-and-reg"
MIK_DECK_DETAIL_API = "https://tcg.mik.moe/api/v3/deck/detail"
MIK_DECK_CORE_API = "https://tcg.mik.moe/api/v3/deck/core-card"
MIK_DECKS_URL = "https://tcg.mik.moe/decks"
MIK_SERIES_URL = "https://tcg.mik.moe/tournaments/series"
BILIBILI_SPACE_API = "https://api.bilibili.com/x/space/arc/search"
BILIBILI_SEARCH_API = "https://api.bilibili.com/x/web-interface/search/type"
FEATURED_TOURNAMENT_ID = 3098
FEATURED_DECK_ID = 593481
LOST_BOX_CATEGORY_ID = 247
VIDEO_WINDOW_DAYS = 30

FEATURED_CASES = [
    {
        "slug": "hangzhou-lost-toolbox",
        "tournament_id": 3098,
        "deck_id": 593481,
        "compare_variant_id": 247,
        "rank": 1,
        "deck_name": "非主流放逐 Box",
        "display_date": "2026.05.01",
        "display_city": "杭州",
        "fallback_players": 180,
        "title": "杭州 180 人冠军：非主流放逐 Box 的工具箱化",
        "thesis": "它不是普通放逐 Box，而是把放逐启动、土龙抽牌和多属性攻击手合在一起的反环境工具箱。",
    },
    {
        "slug": "xian-dragapult-dusknoir",
        "tournament_id": 3093,
        "deck_id": 598722,
        "compare_variant_id": 332,
        "rank": 1,
        "deck_name": "多龙巴鲁托 黑夜魔灵",
        "display_date": "2026.05.01",
        "display_city": "西安",
        "fallback_players": 122,
        "title": "西安 122 人冠军：多龙黑夜魔灵把伤害变成选择题",
        "thesis": "这套牌的重点不是单纯提高爆发，而是用多龙的铺伤和黑夜魔灵的自爆伤害，把对手的进化链和奖赏卡规划同时打乱。",
    },
    {
        "slug": "chongqing-raging-bolt-ogerpon",
        "tournament_id": 3108,
        "deck_id": 599382,
        "compare_variant_id": 333,
        "rank": 1,
        "deck_name": "猛雷鼓 厄诡椪",
        "display_date": "2026.05.01",
        "display_city": "重庆",
        "fallback_players": 76,
        "title": "重庆冠军猛雷鼓：速度牌也可以带针对位",
        "thesis": "猛雷鼓的价值不只是快，而是在稳定能量循环之外加入阻碍之塔和多攻击手，让热门进化牌来不及舒服展开。",
    },
]

OFFICIAL_ALLOWED_CATEGORIES = {"赛事活动", "商品", "推广"}
USER_AGENT = "PTCGDeckAgentCommunityBot/0.1 (+https://ptcg.skillserver.cn/community)"


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def request_text(url: str, timeout: float = 12.0) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read().decode("utf-8", errors="replace")


def post_json(url: str, payload: dict[str, Any], timeout: float = 12.0) -> dict[str, Any]:
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={
            "Content-Type": "application/json",
            "User-Agent": USER_AGENT,
            "Origin": "https://tcg.mik.moe",
            "Referer": "https://tcg.mik.moe/",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8", errors="replace"))


def fetch_json(url: str, timeout: float = 12.0) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (PTCGDeckAgentCommunityBot/0.1)",
            "Referer": "https://www.bilibili.com/",
        },
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8", errors="replace"))


def clean_text(value: str) -> str:
    value = html.unescape(value or "")
    value = re.sub(r"<\s*br\s*/?\s*>", " ", value, flags=re.I)
    value = re.sub(r"<[^>]+>", " ", value)
    value = re.sub(r"\s+", " ", value).strip()
    return value


def shorten(value: str, limit: int) -> str:
    value = clean_text(value)
    if len(value) <= limit:
        return value
    return value[: max(0, limit - 1)].rstrip() + "…"


def parse_rss_date(value: str) -> str:
    if not value:
        return ""
    try:
        parsed = email.utils.parsedate_to_datetime(value)
        return parsed.astimezone().isoformat(timespec="seconds")
    except (TypeError, ValueError):
        return value


def fetch_official_updates(notices: list[str]) -> list[dict[str, Any]]:
    try:
        xml_text = request_text(OFFICIAL_RSS)
        root = ElementTree.fromstring(xml_text)
    except (urllib.error.URLError, TimeoutError, ElementTree.ParseError) as exc:
        notices.append(f"官方 RSS 获取失败：{exc}")
        return []

    updates: list[dict[str, Any]] = []
    for item in root.findall("./channel/item"):
        title = clean_text(item.findtext("title", default=""))
        link = clean_text(item.findtext("link", default=""))
        published_at = parse_rss_date(item.findtext("pubDate", default=""))
        description_raw = item.findtext("description", default="")
        description = clean_text(description_raw.split("<p><a", 1)[0])
        categories = [clean_text(category.text or "") for category in item.findall("category")]
        if not any(category in OFFICIAL_ALLOWED_CATEGORIES for category in categories):
            continue
        category = next((name for name in categories if name in OFFICIAL_ALLOWED_CATEGORIES), "官方消息")
        display_category = "活动" if category == "推广" else category
        updates.append(
            {
                "title": title,
                "summary": summarize_official(title, description, display_category),
                "category": display_category,
                "published_at": published_at,
                "source_name": "宝可梦中国",
                "url": link,
            }
        )
        if len(updates) >= 8:
            break
    return updates


def summarize_official(title: str, description: str, category: str) -> str:
    core = shorten(description, 90)
    if not core:
        core = shorten(title, 90)
    if category == "赛事活动":
        return f"赛事相关更新：{core}"
    if category == "商品":
        return f"商品信息更新：{core}"
    return f"活动信息更新：{core}"


def fetch_current_format(notices: list[str]) -> str:
    try:
        payload = post_json(MIK_HOME_API, {})
        data = payload.get("data") or {}
        current_format = str(data.get("format") or "").strip()
        return current_format or "FGH-CSV8C"
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        notices.append(f"环境格式获取失败，使用默认 FGH-CSV8C：{exc}")
        return "FGH-CSV8C"


def fetch_meta_decks(current_format: str, notices: list[str]) -> list[dict[str, Any]]:
    payload = {
        "topCuts": 0,
        "isVariant": False,
        "regulationMark": current_format,
        "hasTeam": False,
        "onlyTeam": False,
    }
    try:
        response = post_json(MIK_DECK_API, payload)
        entries = ((response.get("data") or {}).get("list") or [])[:8]
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        notices.append(f"卡组环境获取失败：{exc}")
        return []

    decks: list[dict[str, Any]] = []
    for index, entry in enumerate(entries, start=1):
        share = float(entry.get("share") or 0)
        points_share = float(entry.get("share2") or 0)
        conversion = points_share / share if share > 0 else 0
        trend = "稳定热门"
        if conversion >= 1.1:
            trend = "成绩转化偏高"
        elif conversion <= 0.9:
            trend = "出场多但转化一般"
        decks.append(
            {
                "rank": index,
                "name": str(entry.get("name") or "未知卡组"),
                "label": str(entry.get("label") or "-"),
                "share": round(share, 4),
                "points_share": round(points_share, 4),
                "trend": trend,
                "coach_note": build_deck_note(str(entry.get("name") or "这套牌"), share, conversion),
                "source_url": MIK_DECKS_URL,
            }
        )
    return decks


def build_deck_note(name: str, share: float, conversion: float) -> str:
    percent = share * 100
    if conversion >= 1.1:
        return f"{name}不仅常见，积分占比也更亮眼；练习时要重点准备前中期压制与资源交换。"
    if percent >= 12:
        return f"{name}出场率很高，属于必须熟悉的对局；先把起手展开和关键反制路线练稳。"
    return f"{name}仍在主流视野内，适合作为第二梯队测试对象，补齐弱点对局。"


def fetch_tournaments(notices: list[str]) -> list[dict[str, Any]]:
    try:
        response = post_json(MIK_SERIES_API, {"page": 1, "pageSize": 8})
        entries = (response.get("data") or {}).get("list") or []
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        notices.append(f"赛事系列获取失败：{exc}")
        return []

    tournaments: list[dict[str, Any]] = []
    for entry in entries[:6]:
        start = format_date(entry.get("startDate"))
        end = format_date(entry.get("endDate"))
        status = map_status(str(entry.get("status") or ""))
        name = str(entry.get("name") or "未命名赛事")
        tournament_num = int(entry.get("tournamentNum") or 0)
        tournaments.append(
            {
                "name": name,
                "status": status,
                "date_range": f"{start} - {end}" if start and end and start != end else start or end,
                "location": "全国/多地" if "城市赛" in name else "",
                "summary": f"当前记录 {tournament_num} 个子赛事，建议参赛玩家以官方报名与现场信息为准。",
                "url": str(entry.get("link") or MIK_SERIES_URL),
            }
        )
    return tournaments


def fetch_featured_case_study(notices: list[str]) -> dict[str, Any]:
    return fetch_case_study(FEATURED_CASES[0], notices)


def fetch_case_study(case: dict[str, Any], notices: list[str]) -> dict[str, Any]:
    detail: dict[str, Any] = {}
    deck: dict[str, Any] = {}
    core: dict[str, Any] = {}
    tournament_id = int(case["tournament_id"])
    deck_id = int(case["deck_id"])
    compare_variant_id = int(case["compare_variant_id"])
    try:
        detail = (post_json(MIK_TOURNAMENT_DETAIL_API, {"tournamentId": tournament_id}).get("data") or {})
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        notices.append(f"焦点赛事 {tournament_id} 详情获取失败：{exc}")
    try:
        deck = (post_json(MIK_DECK_DETAIL_API, {"deckId": deck_id}).get("data") or {})
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        notices.append(f"焦点卡表 {deck_id} 获取失败：{exc}")
    try:
        core = (post_json(MIK_DECK_CORE_API, {"variant": compare_variant_id, "showPopular": True}).get("data") or {})
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        notices.append(f"主流构筑 {compare_variant_id} 投入数据获取失败：{exc}")

    cards = deck.get("cards") or []
    core_cards = core.get("list") or []
    differences = compare_deck_to_core(cards, core_cards)
    deck_cards = [
        {
            "name": card.get("cardName", ""),
            "count": int(card.get("count") or 0),
            "type": card.get("cardType", ""),
            "set_code": card.get("setCode", ""),
            "card_index": card.get("cardIndex", ""),
            "image_url": build_card_image_url(card),
        }
        for card in cards
    ]
    deck_cards.sort(key=lambda item: (str(item["type"]), str(item["name"])))

    tournament_name = detail.get("name") or f"2026城市赛第二赛季 - {case['display_city']}"
    participant_count = int(detail.get("participantCount") or case.get("fallback_players") or 0)
    location = detail.get("location") or case.get("display_city") or ""
    date = format_date(detail.get("date") or detail.get("endDate") or case.get("display_date") or "")
    variant = deck.get("variant") or {}
    return {
        "slug": case["slug"],
        "title": case["title"],
        "tournament": {
            "id": tournament_id,
            "name": tournament_name,
            "date": date,
            "location": location,
            "participant_count": participant_count,
            "rank": int(case.get("rank") or 1),
            "url": f"https://tcg.mik.moe/tournaments/{tournament_id}",
            "why_it_matters": [
                f"这是 {date} 已结束城市赛样本，{location} {participant_count} 人参赛，时间足够新。",
                f"该卡组取得第 {int(case.get('rank') or 1)} 名，适合作为近期练牌样本。",
                "解读重点放在构筑取舍，而不是把名次当成唯一答案。",
            ],
        },
        "deck": {
            "id": deck_id,
            "deck_code": deck.get("deckCode") or "",
            "name": case.get("deck_name") or variant.get("variantName") or "焦点卡组",
            "variant_id": variant.get("variantId") or compare_variant_id,
            "variant_name": variant.get("variantName") or case.get("deck_name") or "未知卡组",
            "url": f"https://tcg.mik.moe/decks/list/{deck_id}",
            "compare_url": f"https://tcg.mik.moe/decks/{compare_variant_id}?all=true",
            "cards": deck_cards,
        },
        "coach_read": {
            "headline": case["thesis"],
        },
        "differences": differences,
    }


def build_card_image_url(card: dict[str, Any]) -> str:
    set_code = str(card.get("setCode") or "").strip()
    card_index = str(card.get("cardIndex") or "").strip()
    if not set_code or not card_index:
        return ""
    return f"https://tcg.mik.moe/static/img/{urllib.parse.quote(set_code)}/{urllib.parse.quote(card_index)}.png"


def compare_deck_to_core(cards: list[dict[str, Any]], core_cards: list[dict[str, Any]]) -> dict[str, Any]:
    deck_counts = {str(card.get("cardName", "")): float(card.get("count") or 0) for card in cards}
    core_average = {str(card.get("cardName", "")): float(card.get("averageUsage") or 0) for card in core_cards}
    over: list[dict[str, Any]] = []
    under: list[dict[str, Any]] = []
    for name, count in deck_counts.items():
        average = core_average.get(name, 0.0)
        delta = count - average
        if delta >= 0.75:
            over.append({"name": name, "count": int(count), "mainstream_average": round(average, 2), "delta": round(delta, 2)})
    for name, average in core_average.items():
        if average < 0.75 or name in deck_counts:
            continue
        under.append({"name": name, "count": 0, "mainstream_average": round(average, 2), "delta": round(-average, 2)})
    over.sort(key=lambda item: (-float(item["delta"]), str(item["name"])))
    under.sort(key=lambda item: (float(item["delta"]), str(item["name"])))
    return {
        "over_indexed": over[:8],
        "under_indexed": under[:8],
    }


def format_date(value: Any) -> str:
    text = str(value or "")
    if not text:
        return ""
    return text[:10].replace("-", ".")


def map_status(status: str) -> str:
    return {
        "ongoing": "进行中",
        "upcoming": "即将开始",
        "ended": "已结束",
    }.get(status, status or "未知")


def build_videos(creators: dict[str, Any], notices: list[str]) -> list[dict[str, Any]]:
    exclude = [str(item) for item in creators.get("exclude_keywords", [])]
    include = [str(item) for item in creators.get("include_keywords", [])]
    videos: list[dict[str, Any]] = []
    cutoff = datetime.now(timezone.utc).astimezone() - timedelta(days=VIDEO_WINDOW_DAYS)
    seen: set[str] = set()
    for creator in creators.get("bilibili", []):
        name = str(creator.get("name") or "")
        candidates = fetch_bilibili_creator_videos(creator, notices)
        candidates.extend(creator.get("seed_videos", []))
        for item in candidates:
            title = str(item.get("title") or "")
            published_at = str(item.get("published_at") or "")
            published_time = parse_iso_datetime(published_at)
            if published_time is None or published_time < cutoff:
                continue
            summary_raw = str(item.get("summary") or item.get("description") or "")
            tags = str(item.get("tags") or "")
            haystack = f"{title} {summary_raw} {tags}"
            if any(keyword in haystack for keyword in exclude):
                continue
            if include and not any(keyword in haystack for keyword in include):
                continue
            url = str(item.get("url") or creator.get("space_url") or "")
            key = url or title
            if key in seen:
                continue
            seen.add(key)
            summary = shorten(summary_raw, 120) or build_default_video_summary(title)
            videos.append(
                {
                    "title": title,
                    "summary": summary,
                    "why_watch": build_video_intro(title, summary),
                    "creator": name,
                    "category": classify_video(title, summary, str(item.get("category") or creator.get("default_role") or "")),
                    "published_at": published_at,
                    "url": url,
                    "confidence": 0.82 if item.get("url") else 0.65,
                }
            )
    if not videos:
        notices.append(f"B 站白名单近 {VIDEO_WINDOW_DAYS} 天暂无符合规则的打牌视频，旧环境视频不会进入推荐位。")
    videos.sort(key=lambda item: str(item.get("published_at") or ""), reverse=True)
    return videos[:6]


def fetch_bilibili_creator_videos(creator: dict[str, Any], notices: list[str]) -> list[dict[str, Any]]:
    uid = str(creator.get("uid") or "")
    name = str(creator.get("name") or uid)
    if not uid:
        return []
    query = urllib.parse.urlencode(
        {
            "mid": uid,
            "ps": 30,
            "tid": 0,
            "pn": 1,
            "keyword": "",
            "order": "pubdate",
            "jsonp": "jsonp",
        }
    )
    try:
        payload = fetch_json(f"{BILIBILI_SPACE_API}?{query}")
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        videos = search_bilibili_creator_videos(creator, notices)
        if videos:
            notices.append(f"B 站 {name} 空间接口受限，已通过搜索接口补抓最新视频。")
            return videos
        notices.append(f"B 站 {name} 最新视频获取失败，使用本地种子兜底：{exc}")
        return []
    if int(payload.get("code") or 0) != 0:
        videos = search_bilibili_creator_videos(creator, notices)
        if videos:
            notices.append(f"B 站 {name} 空间接口受限，已通过搜索接口补抓最新视频。")
            return videos
        notices.append(f"B 站 {name} 最新视频获取失败，使用本地种子兜底：{payload.get('message') or payload.get('code')}")
        return []
    raw_list = (((payload.get("data") or {}).get("list") or {}).get("vlist") or [])
    videos: list[dict[str, Any]] = []
    for entry in raw_list:
        created = entry.get("created")
        published_at = ""
        if created:
            published_at = datetime.fromtimestamp(int(created), tz=timezone.utc).astimezone().isoformat(timespec="seconds")
        bvid = str(entry.get("bvid") or "")
        aid = str(entry.get("aid") or "")
        videos.append(
            {
                "title": clean_text(str(entry.get("title") or "")),
                "summary": clean_text(str(entry.get("description") or "")),
                "tags": clean_text(str(entry.get("tag") or entry.get("tags") or "")),
                "published_at": published_at,
                "url": f"https://www.bilibili.com/video/{bvid}/" if bvid else f"https://www.bilibili.com/video/av{aid}/",
            }
        )
    return videos


def search_bilibili_creator_videos(creator: dict[str, Any], notices: list[str]) -> list[dict[str, Any]]:
    uid = str(creator.get("uid") or "")
    name = str(creator.get("name") or uid)
    if not uid:
        return []
    queries = [f"{name} PTCG", f"{name} 卡组"]
    if name.endswith("513"):
        queries.append("月海513 PTCG")
    videos: list[dict[str, Any]] = []
    seen: set[str] = set()
    for keyword in dict.fromkeys(queries):
        query = urllib.parse.urlencode({"search_type": "video", "keyword": keyword})
        try:
            payload = fetch_json(f"{BILIBILI_SEARCH_API}?{query}")
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            notices.append(f"B 站 {name} 搜索接口获取失败：{exc}")
            continue
        if int(payload.get("code") or 0) != 0:
            notices.append(f"B 站 {name} 搜索接口获取失败：{payload.get('message') or payload.get('code')}")
            continue
        for entry in ((payload.get("data") or {}).get("result") or []):
            if str(entry.get("mid") or "") != uid:
                continue
            bvid = str(entry.get("bvid") or "")
            aid = str(entry.get("aid") or "")
            key = bvid or aid
            if not key or key in seen:
                continue
            seen.add(key)
            created = entry.get("pubdate")
            published_at = ""
            if created:
                published_at = datetime.fromtimestamp(int(created), tz=timezone.utc).astimezone().isoformat(timespec="seconds")
            videos.append(
                {
                    "title": clean_text(str(entry.get("title") or "")),
                    "summary": clean_text(str(entry.get("description") or "")),
                    "tags": clean_text(str(entry.get("tag") or entry.get("tags") or "")),
                    "published_at": published_at,
                    "url": f"https://www.bilibili.com/video/{bvid}/" if bvid else f"https://www.bilibili.com/video/av{aid}/",
                }
            )
    videos.sort(key=lambda item: str(item.get("published_at") or ""), reverse=True)
    return videos


def parse_iso_datetime(value: str) -> datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone()


def classify_video(title: str, summary: str, default_category: str) -> str:
    allowed = {"环境讲解", "卡组教学", "对局复盘", "赛事备战"}
    if default_category in allowed:
        return default_category
    haystack = f"{title} {summary}"
    if "复盘" in haystack or "对局" in haystack:
        return "对局复盘"
    if "备战" in haystack or "大师赛" in haystack or "城市赛" in haystack:
        return "赛事备战"
    if "环境" in haystack:
        return "环境讲解"
    if "卡组" in haystack or "构筑" in haystack or "教学" in haystack:
        return "卡组教学"
    return default_category or "卡组教学"


def build_default_video_summary(title: str) -> str:
    if "环境" in title:
        return "围绕当前环境进行讲解，适合练牌前快速校准热门卡组和构筑取舍。"
    if "复盘" in title or "对局" in title:
        return "通过对局或复盘展开思路，适合学习关键回合的资源交换和奖赏卡规划。"
    return "围绕卡组选择或构筑思路展开，适合用作当天练牌前的参考材料。"


def build_video_intro(title: str, summary: str) -> str:
    topic = "这条视频"
    if "环境" in title or "环境" in summary:
        topic = "这条环境向视频"
    elif "卡组" in title or "构筑" in title or "教学" in title or "技巧" in title or "卡组" in summary or "构筑" in summary:
        topic = "这条卡组教学"
    elif "复盘" in title or "对局" in title or "复盘" in summary or "对局" in summary:
        topic = "这条对局复盘"
    return f"{topic}适合作为当天练牌前的补充材料。先看作者如何定义对局目标，再把其中的构筑取舍放回你自己的环境里验证。"


def build_environment_briefing(current_format: str, meta_decks: list[dict[str, Any]], case_studies: list[dict[str, Any]]) -> dict[str, Any]:
    top_deck = meta_decks[0]["name"] if meta_decks else "沙奈朵"
    ranked_case_studies = sorted(
        case_studies,
        key=lambda case: (
            str((case.get("tournament") or {}).get("date") or ""),
            int((case.get("tournament") or {}).get("participant_count") or 0),
        ),
        reverse=True,
    )
    articles = [build_environment_article(current_format, meta_decks, case_study) for case_study in ranked_case_studies[:3]]
    first_article = articles[0] if articles else {}
    first_source = first_article.get("source") or {}
    first_hero = first_article.get("hero") or {}

    source_signals: list[dict[str, str]] = [
        {
            "label": "环境靶子",
            "value": f"{top_deck}占比高",
            "note": "高占比不是直接抄牌答案，而是今天练牌时最该被针对的靶子。",
        },
        {
            "label": "今日卡表",
            "value": first_hero.get("deck_name", "焦点构筑"),
            "note": "今天只推一套可导入卡组，先把它打透，再决定要不要抄牌。",
        },
        {
            "label": "赛事样本",
            "value": f"{first_source.get('date', '')} {first_source.get('city', '')}".strip() or "近期已结束比赛",
            "note": f"{first_source.get('players', 0)} 人参赛样本，优先看已结束、有名次、有卡表的比赛。",
        },
        {
            "label": "练牌闭环",
            "value": "复制链接导入游戏",
            "note": "卡组管理支持 tcg.mik.moe 卡表链接；页面只负责给出今天最值得练的一套。",
        },
    ]

    title = "今日练牌任务：理解一套能惩罚热门环境的卡组"
    subtitle = f"今天只看一件事：{first_hero.get('deck_name', '焦点构筑')} 为什么值得导入游戏练。"
    return {
        "name": "环境解读",
        "title": title,
        "subtitle": subtitle,
        "updated_label": "每日自动生成",
        "source_signals": source_signals,
        "article": first_article,
        "articles": articles,
    }


def build_environment_article(current_format: str, meta_decks: list[dict[str, Any]], case_study: dict[str, Any]) -> dict[str, Any]:
    tournament = case_study.get("tournament") or {}
    deck = case_study.get("deck") or {}
    differences = case_study.get("differences") or {}
    over = differences.get("over_indexed") or []
    under = differences.get("under_indexed") or []
    signal_city = tournament.get("location") or ""
    signal_date = tournament.get("date") or ""
    signal_players = tournament.get("participant_count") or 0
    variant_name = deck.get("variant_name") or deck.get("name") or "焦点卡组"
    over_text = "、".join(f"{item['name']}×{item['count']}" for item in over[:4]) or "稳定组件"
    under_text = "、".join(item["name"] for item in under[:4]) or "部分传统一奖组件"
    article_sections = build_article_sections(case_study, over_text, under_text)
    return {
        "slug": case_study.get("slug") or str(deck.get("id") or ""),
        "hero": {
            "title": case_study.get("title") or f"{variant_name} 近期样本",
            "deck_name": deck.get("name") or variant_name,
            "variant_name": variant_name,
            "tournament": f"{signal_date} · {signal_city} · {signal_players} 人 · 第 {tournament.get('rank', 1)} 名",
            "thesis": (case_study.get("coach_read") or {}).get("headline") or "这套牌值得作为今天的训练样本。",
        },
        "source": {
            "city": signal_city,
            "date": signal_date,
            "players": signal_players,
            "rank": tournament.get("rank", 1),
            "format": current_format,
        },
        "sections": article_sections,
        "deck_snapshot": {
            "title": "卡组图片快照",
            "source": "tcg.mik.moe",
            "source_url": deck.get("url") or "",
            "import_url": deck.get("url") or "",
            "deck_id": deck.get("id") or "",
            "deck_code": deck.get("deck_code") or "",
            "cards": deck.get("cards") or [],
        },
        "links": [
            {
                "label": "打开可导入卡表",
                "url": deck.get("url") or "",
            },
            {
                "label": f"查看{variant_name}统计",
                "url": deck.get("compare_url") or "",
            },
            {
                "label": "查看赛事详情",
                "url": tournament.get("url") or "",
            },
        ],
    }


def build_article_sections(case_study: dict[str, Any], over_text: str, under_text: str) -> list[dict[str, Any]]:
    slug = str(case_study.get("slug") or "")
    tournament = case_study.get("tournament") or {}
    city = tournament.get("location") or ""
    date = tournament.get("date") or ""
    players = tournament.get("participant_count") or 0

    if slug == "xian-dragapult-dusknoir":
        return [
            {
                "heading": "今天的判断",
                "body": "多龙巴鲁托黑夜魔灵不是单纯靠二阶段牌体质取胜，而是用伤害指示物制造多个同时要回答的问题。沙奈朵、多龙和各类二阶段牌变多时，能把伤害分散到备战区并强行改写奖赏卡节奏的牌，会更容易逼对手犯错。",
                "bullets": [
                    f"样本来自 {date} {city} 城市赛，参赛人数 {players}，冠军样本足够新。",
                    "它击穿的是一个有沙奈朵和喷火龙追赶的环境，因此重点不是“多龙很强”，而是它如何让进化牌失去舒服展开的回合。",
                ],
            },
            {
                "heading": "构筑上最值得看哪里",
                "body": "这套牌保留了派帕、洛托姆V、森林封印石的稳定轴，但黑夜魔灵线没有无限堆厚，而是用 2-1-2 形成够用的爆点。它更像一套能稳定启动的多龙，而不是为了黑夜魔灵牺牲全部一致性的极端构筑。",
                "bullets": [
                    f"比主流同型更重视：{over_text}。",
                    f"相对降低或放弃：{under_text}。",
                    "光辉胡地让多龙铺伤更有转化率，配合黑夜魔灵自爆伤害，可以把原本差一点的击倒线变成真实威胁。",
                ],
            },
            {
                "heading": "为什么它适合打热门环境",
                "body": "沙奈朵和其他进化牌都需要在备战区保留关键组件。多龙的铺伤会逼对手提前进化、提前治疗或改变站位，而黑夜魔灵则让这些被铺过伤害的目标随时可能变成奖赏卡。",
                "bullets": [
                    "对手如果铺得慢，会被多龙正面攻击拖住节奏；铺得快，又会给备战区伤害和黑夜魔灵制造目标。",
                    "月月熊赫月ex和老大的指令提高了终盘转换能力，说明这套牌重视最后两张奖赏卡怎么收。",
                    "练这套时不要只练第一只多龙怎么立起来，更要练“哪一回合该用黑夜魔灵换奖赏卡节奏”。",
                ],
            },
            {
                "heading": "今天怎么练",
                "body": "训练重点是伤害计算和奖赏卡路径，而不是机械展开。",
                "bullets": [
                    "练 5 局对沙奈朵：每局记录黑夜魔灵第一次自爆前，备战区已经有几个可被收掉的目标。",
                    "练 3 局对猛雷鼓或密勒顿：测试自己能否在高速度压力下仍然稳定立起第一只多龙。",
                    "复盘时只问一个问题：这局输是因为没有展开，还是因为伤害指示物没有放到会变成奖赏卡的位置。",
                ],
            },
        ]

    if slug == "chongqing-raging-bolt-ogerpon":
        return [
            {
                "heading": "今天的判断",
                "body": "猛雷鼓厄诡椪是典型快攻，但这份重庆冠军样本的价值在于它没有只堆速度。它在主引擎之外加入阻碍之塔、宝可梦捕捉器和沙铁皮/爬地翅这样的分支攻击手，让对手不容易只按一种防线规划。",
                "bullets": [
                    f"样本来自 {date} {city} 城市赛，参赛人数 {players}，冠军牌能说明近期快攻仍然有压制力。",
                    "沙奈朵占比高时，能在对手完成资源循环前连续制造二奖压力的牌，天然会提高环境价值。",
                ],
            },
            {
                "heading": "构筑上最值得看哪里",
                "body": "它保持 4 猛雷鼓ex、3 厄诡椪碧草面具ex和 4 奥琳博士的气魄的主轴，但没有把每个位置都投入一致性牌。部分位置被拿来做干扰和覆盖面，这让它更像一套有针对意识的快攻。",
                "bullets": [
                    f"比主流同型更重视：{over_text}。",
                    f"相对降低或放弃：{under_text}。",
                    "3 宝可梦捕捉器看起来有波动，但在快攻牌里，它的意义是把对手尚未准备好的二奖点提前拉上来。",
                ],
            },
            {
                "heading": "为什么它可能赢在近期环境",
                "body": "如果环境里沙奈朵、多龙、帕路奇亚黑夜魔灵都需要两回合以上建立盘面，猛雷鼓就能用前两回合的高伤害迫使对手交资源防守。阻碍之塔还会让依赖工具的卡组付出额外成本。",
                "bullets": [
                    "能量回收和大地容器保证攻击续航，避免快攻只打一波。",
                    "沙铁皮、爬地翅给了不同弱点和奖赏卡交换路线，减少被单一防守策略锁死的风险。",
                    "它不是教你无脑抢攻，而是教你在快攻里保留足够的针对位。",
                ],
            },
            {
                "heading": "今天怎么练",
                "body": "训练重点是前两回合决策，以及每一张干扰牌是否真的帮你多拿了一张奖赏卡。",
                "bullets": [
                    "练 5 局后攻：记录第一回合是否能形成真实击倒压力，不能的话缺的是能量、支援者还是换位。",
                    "每次使用宝可梦捕捉器都记录目标，如果目标不是二奖点或关键系统牌，就复盘这次投掷是否值得。",
                    "对沙奈朵练习时，重点测试能否在对手稳定启动前连续处理拉鲁拉丝/奇鲁莉安线。",
                ],
            },
        ]

    return [
        {
            "heading": "今天的判断",
            "body": "环境理解不是看谁占比最高就抄谁，而是判断热门卡组把环境推向了哪里。沙奈朵这类卡组占比高时，能稳定惩罚铺场、二奖点和关键进化链的构筑，反而会成为更值得研究的样本。",
            "bullets": [
                f"样本来自 {date} {city} 城市赛，参赛人数 {players}，时间和样本量都足够新。",
                "冠军牌被系统归到“其他”，这通常意味着它不是标准答案，而是针对环境做过重调的方案。",
            ],
        },
        {
            "heading": "它和主流放逐 Box 的差异",
            "body": "主流放逐 Box 往往保留古月鸟、勾魂眼和顶尖捕捉器等一奖节奏组件；这套牌弱化了传统一奖消耗，转向花疗环环加阿克罗玛快速堆放逐，再用铁臂膀ex、轰鸣月ex、雷公V、月月熊ex按对局选择终结方式。",
            "bullets": [
                f"明显加重的组件：{over_text}。",
                f"主动降低或放弃的组件：{under_text}。",
                "这说明它不追求经典放逐 Box 的一奖慢磨，而是追求更稳定地找到关键资源并用高冲击攻击手改变奖赏卡节奏。",
            ],
        },
        {
            "heading": "为什么它可能脱颖而出",
            "body": "在沙奈朵常见的环境里，单纯跟着主流打一奖消耗并不一定占优。更有威胁的是用多属性攻击手，让对手的铺场和二奖点变成被惩罚的窗口。",
            "bullets": [
                "2-2 土龙轴把友好宝芬从铺花疗环环，扩展成铺抽牌引擎，长轮次比赛更不容易因断资源输掉。",
                "秘密箱、城镇百货、洛托姆V和森林封印石提高找关键牌能力，牺牲部分传统攻击位来换稳定性。",
                "多属性攻击手让对手难以只按一种防线规划，尤其适合攻击高占比热门牌的固定展开路线。",
            ],
        },
        {
            "heading": "今天怎么练",
            "body": "这套牌的价值不在于立刻照抄 60 张，而在于学习它如何用近期赛事样本反推环境弱点。",
            "bullets": [
                "用这套思路练 5 局对沙奈朵：每局记录铁臂膀ex或轰鸣月ex第一次出手的回合，以及这次出手是否改变奖赏卡节奏。",
                "复盘前两回合：花疗环环、阿克罗玛、土龙节节各抽到了多少资源，是否真的比传统放逐 Box 更稳。",
                "不要先照抄 60 张。先理解它为本地环境做了什么取舍，再决定你是否也需要这些取舍。",
            ],
        },
    ]


def build_sources() -> list[dict[str, str]]:
    return [
        {
            "name": "Cryst's Cards Database",
            "url": MIK_DECKS_URL,
            "note": "第三方简中 PTCG 环境、赛事与卡表统计，作为环境解读的主要数据源。",
        },
    ]


def generate(creators_path: Path) -> dict[str, Any]:
    notices: list[str] = [
        "环境与赛事数据来自第三方统计，可能与官方最终结果存在差异。",
        "卡组导入以游戏内卡组管理的 tcg.mik.moe 链接解析能力为准。",
    ]
    current_format = fetch_current_format(notices)
    meta_decks = fetch_meta_decks(current_format, notices)
    case_studies: list[dict[str, Any]] = []
    seen_variants: set[str] = set()
    for case in FEATURED_CASES:
        case_study = fetch_case_study(case, notices)
        deck = case_study.get("deck") or {}
        variant_name = str(deck.get("variant_name") or deck.get("name") or case.get("deck_name") or "")
        if variant_name in seen_variants:
            notices.append(f"跳过重复环境解读卡组：{variant_name}")
            continue
        seen_variants.add(variant_name)
        case_studies.append(case_study)
    return {
        "generated_at": now_iso(),
        "format": current_format,
        "environment_briefing": build_environment_briefing(current_format, meta_decks, case_studies),
        "sources": build_sources(),
        "notices": notices,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate community page JSON data.")
    parser.add_argument("--creators", type=Path, default=DEFAULT_CREATORS)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    data = generate(args.creators)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
