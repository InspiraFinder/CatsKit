"""
CatsKit OCR 包装脚本 — 供 Flutter 通过 Process 调用
用法: python catskit_ocr.py <base64_path>
输出: JSON 到 stdout

识别策略：
  1. 对全图进行 OCR 识别
  2. 按文字横坐标分为左区、中区、右区
  3. 在每个区内按纵坐标聚簇为行组
  4. 对左区、右区只取最下方的行（白色矩形中下方那行数据）
  5. 按格式识别 6 个数据字段
"""
import base64
import json
import re
import sys

import cv2
import numpy as np
from rapidocr_onnxruntime import RapidOCR


def read_image(path: str):
    """支持 Unicode 路径的图片读取"""
    with open(path, 'rb') as f:
        data = f.read()
    img = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError(f"无法解码图片: {path}")
    return img


def cluster_rows(items):
    """将 OCR 结果按 y 中心坐标聚合成行组，返回 [(avg_y, [items])]"""
    if not items:
        return []
    sorted_items = sorted(items, key=lambda r: r["cy"])
    rows = []
    current = [sorted_items[0]]
    for item in sorted_items[1:]:
        prev = current[-1]
        gap = abs(item["cy"] - prev["cy"])
        avg_h = (current[-1]["h"] + item["h"]) / 2
        if gap < avg_h * 0.7:
            current.append(item)
        else:
            rows.append(current)
            current = [item]
    if current:
        rows.append(current)
    result = [(int(np.mean([r["cy"] for r in row])), row) for row in rows]
    result.sort(key=lambda r: r[0])
    return result


def classify_text_items(items, img_w, img_h):
    """
    全图 OCR 后按位置/格式归类为 6 个字段。
    
    布局：
      - 左区 (x < w*0.38):  我方数据 → 只取最下方行
      - 中区 (w*0.38~w*0.62): 分数线, 剩余时间
      - 右区 (x > w*0.62):  敌方数据 → 只取最下方行
    """
    result = {
        "my_score_per_min": "",
        "my_score": "",
        "score_line": "",
        "time_left": "",
        "enemy_score": "",
        "enemy_score_per_min": "",
    }
    if not items:
        return result

    for item in items:
        item["cx"] = item["x"] + item["w"] // 2
        item["cy"] = item["y"] + item["h"] // 2
        item["qx"] = item["x"] + item["w"] // 4  # 左四分之一，避免宽框跨区

    # 只分析顶部 30%
    top_items = [it for it in items if it["cy"] < img_h * 0.30]
    if not top_items:
        return result

    # 用固定百分比划分三区（基于左四分之一坐标）
    lb = int(img_w * 0.38)
    rb = int(img_w * 0.62)
    left = [it for it in top_items if it["qx"] < lb]
    center = [it for it in top_items if lb <= it["qx"] <= rb]
    right = [it for it in top_items if it["qx"] > rb]

    def bottom_row(zone):
        if not zone:
            return []
        rows = cluster_rows(zone)
        return rows[-1][1] if rows else []

    def spm(items):
        """提取每分钟得分：值 1-300，可选 +/-"""
        cand = []
        for it in items:
            t = it["text"].strip().replace(",", "")
            # 分别提取每个带符号的数字
            for m in re.finditer(r'[+\-]?\d+', t):
                raw = m.group(0)
                digits = re.sub(r'[^\d]', '', raw)
                if not digits:
                    continue
                v = int(digits)
                if 1 <= v <= 300:
                    if raw.startswith('-'):
                        normalized = '+' + digits
                    elif raw.startswith('+'):
                        normalized = raw
                    else:
                        normalized = '+' + digits
                    cand.append((normalized, v))
        if cand:
            cand.sort(key=lambda x: -x[1])
            return cand[0][0]
        return ""

    def num(items):
        """提取分数：值 0-150000，排除以 + 开头且 ≤300 的 SPM 值"""
        cand = []
        for it in items:
            t = it["text"].strip().replace(",", "")
            # 分别提取每个数字
            for m in re.finditer(r'\d+', t):
                digits = m.group(0)
                if not digits:
                    continue
                v = int(digits)
                if v < 0 or v > 150000:
                    continue
                # 排除 SPM 格式：以 + 开头且值 ≤ 300
                prefix_start = max(0, m.start() - 1)
                prefix = t[prefix_start:m.start()]
                if (prefix in ('+', '-')) and v <= 300:
                    continue
                cand.append((digits, v))
        if cand:
            cand.sort(key=lambda x: -x[1])
            return cand[0][0]
        return ""

    def tm(items):
        """提取时间文本：\"Xh Ym\" / \"X时Y分\" / \"X分\" / \"X时\" 等"""
        # 优先匹配含有明确时间单位的完整文本
        for it in items:
            t = it["text"].strip()
            # 有中文时间单位的文本 -> 提取纯净时间部分
            if "分" in t or "时" in t:
                # 宽松匹配：数字后可能有若干噪声字符再到单位（如 "8B时"）
                hour_m = re.search(r'(\d+)\S*\s*时', t)
                min_m = re.search(r'(\d+)\s*分', t)
                hour = hour_m.group(1) if hour_m else None
                minute = min_m.group(1) if min_m else None
                if hour and minute:
                    return f"{hour}时{minute}分"
                if hour:
                    return f"{hour}时"
                if minute:
                    return f"{minute}分"
                return t
            if re.search(r'\d+\s*[hm]', t, re.IGNORECASE):
                return t
        # 回退：扫描含两个数字的文本（如 "20 49" 可能是时间）
        for it in items:
            t = it["text"].strip()
            nums = re.findall(r'\d+', t)
            if len(nums) >= 2:
                v1, v2 = int(nums[0]), int(nums[1])
                if 0 <= v1 <= 23 and 0 <= v2 <= 59:
                    return f"{v1}时{v2}分"
        return ""

    # 左区取最下行
    lb_row = bottom_row(left)
    result["my_score_per_min"] = spm(lb_row)
    result["my_score"] = num(lb_row)

    # 右区取最下行
    rb_row = bottom_row(right)
    result["enemy_score"] = num(rb_row)
    result["enemy_score_per_min"] = spm(rb_row)

    # 中区取全部
    result["time_left"] = tm(center)
    result["score_line"] = num(center)

    return result


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "请指定图片路径"}, ensure_ascii=False))
        return 1

    try:
        img_path = base64.b64decode(sys.argv[1]).decode('utf-8')
    except Exception:
        img_path = sys.argv[1]

    try:
        img = read_image(img_path)
    except Exception as e:
        print(json.dumps({"error": f"读取图片失败: {e}"}, ensure_ascii=False))
        return 1

    h, w = img.shape[:2]

    # 全图 OCR
    ocr = RapidOCR()
    result, elapse = ocr(img)

    if not result:
        print(json.dumps({"texts": [], "count": 0, "fields": {}}, ensure_ascii=False))
        return 0

    items = []
    for item in result:
        box_pts, text, score = item
        xs = [int(p[0]) for p in box_pts]
        ys = [int(p[1]) for p in box_pts]
        items.append({
            "text": text,
            "score": round(float(score), 4),
            "x": min(xs),
            "y": min(ys),
            "w": max(xs) - min(xs),
            "h": max(ys) - min(ys),
        })

    fields = classify_text_items(items, w, h)
    items.sort(key=lambda r: (r["y"], r["x"]))

    output = {"texts": items, "count": len(items), "fields": fields}
    print(json.dumps(output, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
