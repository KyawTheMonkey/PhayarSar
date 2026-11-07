#!/usr/bin/env python3
"""Rebuild the prayer covers without an image model or third-party Python packages.

The catalog is the authority for identity and ordering. The compositions below
are deliberately art-directed, rather than hashes of prayer IDs: the silhouette
should help a reader recognise a prayer even when its title isn't visible.
SVGs contain only flat vector geometry; lettering belongs to the app's
localised UI, not the artwork. Previews require the optional rsvg-convert CLI.
"""

from pathlib import Path
from html import escape
import argparse
import json
import math
import shutil
import subprocess
import xml.etree.ElementTree as ET
import zipfile

PACKAGE = Path(__file__).resolve().parents[2]
OUT = PACKAGE / "Artwork" / "PrayerCovers"
PRAYERS = PACKAGE / "Sources" / "PrayersKit" / "Prayers"
ASSETS = PACKAGE / "Sources" / "PrayersKit" / "Resources" / "PrayerCovers.xcassets"

# Artwork inks, intentionally independent of the app's adaptive UI tokens:
# these are original illustrations whose colours stay fixed in either scheme.
C = {
  "paper": "#F2E5BF", "ink": "#182F32", "teal": "#346963",
  "sage": "#91A68A", "gold": "#DDA547", "rust": "#C65D3B",
  "clay": "#DE9870",
}


def color(value):
  return C.get(value, value)


def rect(x, y, w, h, fill, rx=0):
  return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{color(fill)}"/>'


def circle(x, y, r, fill):
  return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{color(fill)}"/>'


def ellipse(x, y, rx, ry, fill):
  return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{color(fill)}"/>'


def path(d, fill, stroke=None, width=1):
  edge = f' stroke="{color(stroke)}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"' if stroke else ""
  return f'<path d="{d}" fill="{color(fill)}"{edge}/>'


def line(x1, y1, x2, y2, fill, width=8):
  return path(f'M{x1} {y1}L{x2} {y2}', "none", fill, width)


def polygon(points, fill):
  return f'<polygon points="{points}" fill="{color(fill)}"/>'


def group(content, transform):
  return f'<g transform="{transform}">{content}</g>'


def ring(x, y, r, fill, width=12):
  return f'<circle cx="{x}" cy="{y}" r="{r}" fill="none" stroke="{color(fill)}" stroke-width="{width}"/>'


def leaf(x, y, size, fill, angle=0):
  # A broad leaf, with a long pointed tip reminiscent of a bodhi leaf.
  return group(path('M0 105C-12 60-78 30-69-22C-61-73-18-69 0-45C18-69 61-73 69-22C78 30 12 60 0 105Z', fill), f'translate({x} {y}) rotate({angle}) scale({size})')


def lotus(x, y, scale=1, primary="paper", secondary="gold"):
  content = path('M0 20C-94 20-155-32-151-95C-72-96-17-55 0 20Z', secondary)
  content += path('M0 20C94 20 155-32 151-95C72-96 17-55 0 20Z', secondary)
  content += path('M0 20C-69-23-72-110 0-176C72-110 69-23 0 20Z', primary)
  content += path('M-130 27Q0 104 130 27Q0 50-130 27Z', primary)
  return group(content, f'translate({x} {y}) scale({scale})')


def jewel(x, y, size, light="paper", dark="rust"):
  return group(polygon('-80,-25 -42,-78 42,-78 80,-25 0,86', light)
    + polygon('-80,-25 0,-25 0,86', dark)
    + polygon('42,-78 0,-25 80,-25', "gold")
    + polygon('-42,-78 0,-25 42,-78', "clay"), f'translate({x} {y}) scale({size})')


def bowl(x, y, scale=1, fill="ink"):
  return group(path('M-160 0H160C146 113 81 154 0 154C-81 154-146 113-160 0Z', fill)
    + rect(-168, -18, 336, 27, "paper", 10)
    + rect(-68, 147, 136, 22, fill), f'translate({x} {y}) scale({scale})')


def rays(x, y, count, start, end, fill, width=12, phase=0):
  result = ""
  for i in range(count):
    a = math.radians(phase + i * 360 / count)
    result += line(round(x + start * math.cos(a), 2), round(y + start * math.sin(a), 2), round(x + end * math.cos(a), 2), round(y + end * math.sin(a), 2), fill, width)
  return result


def arch(x, y, w, h, fill):
  return path(f'M{x} {y+h}V{y+w/2}a{w/2} {w/2} 0 0 1 {w} 0V{y+h}Z', fill)


def ground(y=640, fill="ink"):
  return rect(24, y, 752, 160, fill)


def okasa():
  s = circle(420, 323, 242, "gold") + polygon('24,624 776,418 776,776 24,776', "teal")
  # Two joined palms are reduced to broad tapering forms, with a single seam.
  s += path('M229 624L291 467L347 359L383 179Q396 152 405 186L410 488L357 641Z', "ink")
  s += path('M571 624L509 467L453 359L417 179Q404 152 395 186L390 488L443 641Z', "paper")
  s += path('M307 479L355 423L368 345Q375 323 387 344L377 460L341 527Z', "clay")
  s += path('M493 479L445 423L432 345Q425 323 413 344L423 460L459 527Z', "gold")
  s += rect(188, 636, 424, 22, "gold") + rect(145, 674, 510, 18, "paper")
  return s


def refuge():
  s = circle(610, 186, 161, "clay") + polygon('24,543 776,331 776,776 24,776', "gold")
  for i, (x, y, f) in enumerate([(122, 280, "teal"), (304, 180, "ink"), (486, 280, "rust")]):
    s += arch(x+14, y+18, 168, 360, "clay") + arch(x, y, 168, 360, f)
    s += jewel(x+84, y+130, .55, "paper", "gold")
  s += rect(100, 659, 600, 23, "ink")
  return s


def request_precepts():
  s = rect(400, 24, 376, 752, "teal") + circle(400, 337, 246, "gold")
  s += lotus(400, 405, .83, "paper", "rust") + bowl(400, 460, 1.13)
  s += path('M111 698L148 596Q162 563 193 582L266 626H361Q388 626 388 650H233L164 725Z', "rust")
  s += path('M689 698L652 596Q638 563 607 582L534 626H439Q412 626 412 650H567L636 725Z', "clay")
  return s


def precepts(n):
  if n == 5:
    s = circle(592, 220, 169, "paper") + path('M24 615Q355 430 776 596V776H24Z', "teal")
    for i in range(5):
      x, y = 176+i*112, 417-abs(i-2)*-22
      s += line(x, y-30, x, 651, "ink", 15) + leaf(x, y-30, .66, "paper" if i % 2 == 0 else "gold", 180)
    s += path('M24 710Q400 600 776 710V776H24Z', "ink")
    return s
  if n == 8:
    s = polygon('24,776 776,24 776,776', "sage") + circle(400, 400, 283, "ink")
    for i in range(8):
      s += group(path('M0-72C-53-121-47-190 0-235C47-190 53-121 0-72Z', "paper" if i % 2 == 0 else "gold"), f'translate(400 400) rotate({i*45})')
    s += circle(400, 400, 71, "rust") + circle(425, 381, 61, "ink")
    return s
  s = polygon('24,540 776,250 776,776 24,776', "rust") + circle(620, 174, 102, "paper")
  for i in range(10):
    x, y = 104+i*60, 469-i*23
    s += arch(x+8, y+10, 42, 190, "ink") + arch(x, y, 42, 190, "paper" if i % 2 == 0 else "gold")
  s += polygon('90,722 90,683 710,446 710,485', "ink")
  return s


def sharing():
  s = circle(263, 226, 157, "gold") + ground(578, "teal")
  for y, rx in [(623, 121), (669, 213), (722, 311)]:
    s += f'<ellipse cx="460" cy="{y}" rx="{rx}" ry="22" fill="none" stroke="{C["paper"]}" stroke-width="10"/>'
  vessel = path('M-92-90H73L97-25L68 108Q-9 150-96 104L-115-19Z', "rust")
  vessel += path('M73-48L165-95L134-15L88 10Z', "ink") + rect(-95, -113, 157, 24, "ink", 8)
  vessel += path('M-70-72H-26L-16 104L-63 98Z', "paper")
  s += group(vessel, 'translate(348 308) rotate(24)')
  s += path('M520 288Q478 433 463 578', "none", "teal", 19)
  s += path('M463 578L460 622', "none", "paper", 19)
  s += circle(460, 623, 15, "gold")
  return s


def radiance():
  s = ""
  for i, f in enumerate(["teal", "sage", "paper", "gold", "clay", "rust"]):
    s += polygon(f'400,340 {24+i*150},776 {174+i*150},776', f)
  s += rays(400, 302, 12, 175, 230, "gold", 10, 15)
  s += jewel(400, 300, 1.45, "paper", "teal")
  return s


def invitation():
  s = circle(597, 169, 109, "gold") + polygon('24,776 24,408 776,682 776,776', "teal")
  for x, y, r in [(163, 171, 14), (291, 120, 10), (454, 209, 12), (646, 371, 12)]:
    s += rays(x, y, 4, 0, r*2, "paper", 6, 0)
  s += arch(234, 308, 332, 355, "paper") + arch(284, 356, 232, 307, "ink")
  s += path('M329 550Q400 453 471 550', "none", "gold", 15)
  s += rect(186, 662, 428, 22, "gold") + rect(139, 701, 522, 18, "paper")
  return s


def buddha_virtues():
  s = circle(400, 387, 268, "gold") + polygon('24,776 24,632 776,449 776,776', "rust")
  s += leaf(400, 375, 2.12, "ink", 180)
  s += path('M400 215V566M400 349L337 300M400 409L470 351', "none", "paper", 12)
  for i in range(9):
    a = math.radians(270+i*40)
    s += circle(round(400+235*math.cos(a), 2), round(387+235*math.sin(a), 2), 13, "paper")
  s += rect(285, 675, 230, 14, "ink")
  return s


def dhamma_virtues():
  s = circle(586, 200, 143, "gold") + polygon('24,537 776,290 776,776 24,776', "teal")
  manuscript = ""
  for i in range(6):
    y = -150+i*55
    manuscript += rect(-241+16, y+16, 482, 43, "ink", 6) + rect(-241, y, 482, 43, "paper", 6)
    manuscript += circle(-193, y+21, 6, "rust") + line(-148, y+21, 150-i*16, y+21, "gold", 6)
  s += group(manuscript, 'translate(400 401) rotate(-13)')
  return s


def sangha_virtues():
  s = circle(612, 174, 147, "clay") + polygon('24,776 24,350 776,662 776,776', "ink")
  for row in range(3):
    for col in range(3):
      x, y = 162+col*169, 148+row*164
      s += arch(x+9, y+12, 138, 141, "ink") + arch(x, y, 138, 141, "gold" if (row+col)%2 else "paper")
      s += path(f'M{x+25} {y+137}L{x+105} {y+42}L{x+117} {y+137}Z', "rust")
  s += rect(162, 684, 476, 16, "gold")
  return s


def virtues_net():
  s = circle(588, 215, 144, "gold") + polygon('24,512 776,257 776,776 24,776', "sage")
  shield = 'M400 126L640 226V427Q630 587 400 694Q170 587 160 427V226Z'
  s += path(shield, "ink") + path('M400 164L604 250V420Q596 555 400 652Q204 555 196 420V250Z', "teal")
  for i in range(5):
    x = 190+i*90
    s += line(x, 262, min(x+215, 590), 540, "sage", 10)
    s += line(800-x, 262, max(585-x, 210), 540, "sage", 10)
  for y in range(3):
    for x in range(3):
      s += circle(291+x*109, 299+y*109, 18, "gold")
  return s


def many_buddhas():
  s = circle(400, 324, 249, "clay")
  for row, count in [(0, 3), (1, 4), (2, 5)]:
    for col in range(count):
      x, y = 400+(col-(count-1)/2)*123, 202+row*168
      s += lotus(x, y+76, .37, "paper", "gold")
    s += rect(400-count*62, 295+row*168, count*124, 16, "ink")
  return s


def sivali():
  s = rect(24, 24, 376, 752, "teal") + circle(490, 302, 202, "gold")
  s += line(584, 222, 584, 687, "ink", 22)
  s += path('M400 238Q585 19 726 238Z', "paper") + path('M584 97L584 238H726Q667 150 584 97Z', "rust")
  s += leaf(245, 346, .8, "paper", -40) + leaf(323, 326, .85, "sage", 40)
  s += bowl(329, 436, 1.1) + ellipse(400, 681, 260, 18, "ink")
  return s


def mangala():
  s = circle(605, 202, 141, "gold")
  s += polygon('24,776 24,589 180,589 180,480 337,480 337,371 494,371 494,262 652,262 652,776', "ink")
  for x, y in [(132, 585), (289, 476), (446, 367), (603, 258)]:
    s += lotus(x, y, .42, "paper", "rust")
  s += polygon('24,719 776,419 776,776 24,776', "teal")
  for i in range(3):
    s += line(111+i*24, 731+i*13, 702, 497+i*21, "gold" if i == 1 else "sage", 9)
  return s


def ratana():
  s = polygon('24,24 776,24 776,319 24,614', "rust")
  s += circle(400, 388, 253, "ink")
  s += jewel(400, 253, 1.16, "paper", "teal")
  s += jewel(256, 481, 1.16, "paper", "rust") + jewel(544, 481, 1.16, "paper", "teal")
  s += path('M198 667Q400 735 602 667', "none", "gold", 16)
  return s


def metta_tree():
  s = circle(593, 182, 122, "gold") + path('M24 649Q400 488 776 649V776H24Z', "sage")
  s += path('M400 357V673M400 493L260 374M400 478L554 347', "none", "ink", 38)
  for x, y, size, angle, f in [(245, 328, 1.5, -56, "teal"), (542, 305, 1.5, 56, "teal"), (400, 237, 1.8, 180, "ink")]:
    s += leaf(x, y, size, f, angle)
  s += lotus(400, 669, .58, "paper", "rust")
  return s


def khanda():
  s = circle(406, 385, 259, "gold") + polygon('24,776 24,664 776,475 776,776', "teal")
  s += path('M546 301C668 394 594 609 408 603C210 598 167 414 269 315C333 254 454 273 458 367C460 431 359 462 321 408', "none", "ink", 67)
  s += path('M526 320Q511 246 569 223Q625 212 636 255Q642 299 585 319Z', "ink")
  s += circle(595, 254, 8, "paper")
  s += leaf(380, 377, 1.05, "paper", 180)
  s += path('M393 421L384 331', "none", "gold", 9)
  return s


def mora():
  s = circle(620, 194, 118, "rust") + ground(650, "ink")
  for i in range(7):
    a = -75+i*25
    feather = path('M0 100C-85-3-76-225 0-332C76-225 85-3 0 100Z', "teal" if i%2 else "ink")
    feather += ellipse(0, -235, 26, 45, "gold") + ellipse(0, -233, 11, 21, "paper")
    s += group(feather, f'translate(400 533) rotate({a})')
  s += path('M356 622Q309 555 366 471L386 413Q376 366 416 357Q466 348 469 387L444 397L430 483Q480 588 435 622Z', "gold")
  s += polygon('459,378 492,393 458,403', "rust") + circle(432, 376, 6, "ink")
  s += line(383, 623, 373, 655, "paper", 9) + line(418, 623, 428, 655, "paper", 9)
  return s


def vatta():
  s = ""
  for x, h in [(88, 260), (198, 160), (655, 237), (735, 350)]:
    s += path(f'M{x-47} 665Q{x-97} {665-h/2} {x} {665-h}Q{x-12} {665-h/3} {x+47} 665Z', "gold")
  s += circle(400, 431, 235, "paper") + circle(400, 431, 193, "teal")
  s += path('M249 523Q400 675 551 523Z', "ink")
  s += ellipse(382, 464, 94, 74, "gold") + circle(448, 413, 47, "gold")
  s += path('M312 450Q370 411 408 464Q368 506 325 489Z', "rust")
  s += polygon('488,413 523,429 489,436', "paper") + circle(461, 405, 7, "ink")
  s += path('M249 523Q400 576 551 523M273 555Q400 601 527 555', "none", "clay", 11)
  return s


def dhajagga():
  s = circle(553, 225, 167, "gold")
  s += polygon('24,660 210,432 391,660', "sage") + polygon('238,776 571,363 776,624 776,776', "teal")
  s += line(295, 160, 295, 667, "ink", 19)
  s += path('M305 182Q419 137 566 189L519 276L566 366Q420 314 305 360Z', "paper")
  s += path('M305 227Q402 190 534 226L519 255Q403 224 305 265Z', "rust")
  s += path('M305 283Q402 245 530 281L545 310Q403 280 305 321Z', "gold")
  s += circle(295, 154, 18, "paper")
  return s


def atanatiya():
  s = circle(400, 400, 281, "sage")
  for a in range(0, 360, 90):
    gate = rect(-92, -280, 184, 118, "ink") + rect(-50, -245, 100, 83, "paper")
    gate += rect(-113, -301, 226, 28, "rust")
    s += group(gate, f'translate(400 400) rotate({a})')
  s += circle(400, 400, 151, "teal") + lotus(400, 460, .73, "paper", "gold")
  return s


def angulimala():
  s = circle(580, 204, 134, "clay") + polygon('24,652 776,394 776,776 24,776', "gold")
  s += arch(166, 139, 468, 511, "ink") + arch(226, 199, 348, 451, "teal")
  s += leaf(400, 367, 1.09, "paper", 180)
  s += path('M268 459Q294 559 400 577Q506 559 532 459Q454 464 400 522Q346 464 268 459Z', "clay")
  s += path('M255 550Q400 697 545 550', "none", "paper", 28)
  s += rect(148, 676, 504, 20, "rust")
  return s


def bojjhanga():
  s = circle(589, 208, 135, "paper") + polygon('24,776 24,607 776,360 776,776', "sage")
  s += path('M224 672Q448 470 496 182', "none", "ink", 16)
  for d, f in [
    ('M274 597C193 604 133 543 130 473C222 471 279 523 274 597Z', 'teal'),
    ('M322 544C333 453 431 426 481 452C454 537 389 560 322 544Z', 'paper'),
    ('M363 476C270 469 233 401 252 330C343 346 373 392 363 476Z', 'gold'),
    ('M404 404C432 321 513 298 566 331C536 407 459 432 404 404Z', 'paper'),
    ('M441 324C360 308 335 241 359 175C434 195 459 249 441 324Z', 'sage'),
    ('M466 263C506 198 568 193 606 226C570 287 521 299 466 263Z', 'gold'),
    ('M486 206C454 149 485 105 530 91C560 152 540 190 486 206Z', 'rust'),
  ]:
    s += path(d, f)
  s += rect(163, 686, 485, 13, "ink")
  return s


def pubbanha():
  s = rays(400, 397, 16, 205, 289, "paper", 15, 0) + circle(400, 397, 176, "gold")
  s += rect(24, 438, 752, 338, "teal")
  for i, (f, w) in enumerate([("paper", 282), ("gold", 215), ("sage", 148)]):
    s += rect(400-w/2, 479+i*54, w, 16, f, 8)
  s += path('M24 690Q230 576 400 690Q570 576 776 690V776H24Z', "ink")
  return s


def maccha():
  s = circle(585, 209, 130, "sage")
  for i in range(7):
    x = 133+i*83
    s += path(f'M{x} {126+(i%2)*36}l-19 42q19 27 38 0Z', "paper")
  s += path('M24 460Q212 381 400 460T776 460V776H24Z', "teal")
  s += path('M24 670Q212 591 400 670T776 670', "none", "sage", 18)
  s += path('M175 525Q349 337 565 505L669 415V624L565 551Q349 719 175 525Z', "gold")
  s += path('M175 525Q290 408 357 430Q264 529 357 619Q290 642 175 525Z', "paper")
  s += path('M387 477Q456 501 478 534Q432 574 383 578Z', "rust")
  s += circle(256, 505, 11, "ink")
  return s


def mahasamaya():
  s = circle(400, 400, 268, "teal") + ring(400, 400, 208, "sage", 3)
  for band, count in [(155, 12), (254, 18), (323, 22)]:
    for i in range(count):
      a = math.radians(i*360/count + (15 if band == 254 else 0))
      s += circle(round(400+band*math.cos(a), 2), round(400+band*math.sin(a), 2), 13 if band != 254 else 17, "gold" if i%3 else "paper")
  s += lotus(400, 454, .74, "paper", "rust")
  return s


def dhammacakka():
  s = polygon('24,666 776,306 776,776 24,776', "gold") + circle(414, 397, 253, "rust")
  s += ring(390, 373, 227, "ink", 37) + ring(390, 373, 190, "paper", 10)
  s += rays(390, 373, 8, 47, 211, "ink", 25, 0)
  s += circle(390, 373, 57, "ink") + circle(390, 373, 25, "paper")
  s += rect(224, 674, 352, 15, "ink") + rect(272, 706, 256, 9, "rust")
  return s


def anatta():
  s = circle(575, 213, 137, "gold")
  # Five shifting open bands; the centre is intentionally unoccupied.
  for i, f in enumerate(["teal", "sage", "paper", "rust", "ink"]):
    y = 273+i*77
    s += path(f'M145 {y}Q325 {y-108} 506 {y-3}', "none", f, 43)
    s += rect(539+i*12, y-5, 46, 37, f, 4) + rect(613+i*8, y+13, 27, 27, f, 3)
  return s


def patthana(full):
  s = circle(400, 400, 271, "teal")
  if not full:
    points = [(246, 254), (548, 231), (594, 478), (388, 613), (205, 483), (396, 385)]
    for i, j in [(0, 1), (1, 2), (2, 3), (3, 4), (4, 0), (0, 5), (1, 5), (2, 5), (3, 5), (4, 5)]:
      s += line(*points[i], *points[j], "sage", 15)
    for i, (x, y) in enumerate(points):
      s += circle(x+7, y+8, 41, "ink") + circle(x, y, 41, "gold" if i%2 else "paper")
    s += circle(396, 385, 16, "rust")
  else:
    points = [(400+241*math.cos(math.radians(i*15-90)), 400+241*math.sin(math.radians(i*15-90))) for i in range(24)]
    for i in range(24):
      x, y = points[i]
      for step in [1, 5]:
        xx, yy = points[(i+step)%24]
        s += line(round(x, 2), round(y, 2), round(xx, 2), round(yy, 2), "sage", 5)
    s += circle(400, 400, 123, "ink") + jewel(400, 400, .85, "paper", "rust")
    for i, (x, y) in enumerate(points):
      s += circle(round(x, 2), round(y, 2), 18, "paper" if i%3 else "gold")
  return s


def ten_directions():
  s = circle(400, 400, 265, "sage")
  for i in range(8):
    s += group(path('M0-113L-23-230L0-268L23-230Z', "paper" if i%2 else "gold"), f'translate(400 400) rotate({i*45})')
  s += ring(400, 400, 111, "ink", 18) + lotus(400, 443, .49, "paper", "rust")
  s += polygon('400,84 376,121 424,121', "paper") + polygon('400,716 376,679 424,679', "paper")
  return s


def metta_practice():
  s = circle(400, 371, 264, "clay") + polygon('24,776 24,655 776,474 776,776', "teal")
  for r in [245, 194, 143]:
    s += path(f'M{400-r} 399a{r} {r} 0 0 1 {r*2} 0', "none", "paper", 17)
  s += lotus(400, 566, 1.07, "paper", "gold")
  s += path('M138 688Q400 606 662 688', "none", "sage", 15)
  return s


# Each entry follows manifest order. Captions describe artistic associations,
# not canonical emblems or claims about the effects of recitation.
DESIGNS = [
  ("okasa", "Okasa · Homage", "Joined palms and a quiet rising sun", "paper", okasa),
  ("saranagamana", "The Three Refuges", "Three sheltered jewels", "paper", refuge),
  ("requesting-precepts", "Requesting the Precepts", "An offered bowl and lotus", "paper", request_precepts),
  ("five-precepts", "The Five Precepts", "Five upright leaves rooted in a common ground", "rust", lambda: precepts(5)),
  ("eight-precepts", "The Eight Precepts", "Eight petals surrounding a quiet moon", "paper", lambda: precepts(8)),
  ("ten-precepts", "The Ten Precepts", "Ten pillars following an ascending path", "teal", lambda: precepts(10)),
  ("sharing-merit", "Sharing Merit", "Libation water spreading into widening ripples", "paper", sharing),
  ("diamond-radiance", "Diamond Radiance", "A faceted jewel and six broad bands of light", "ink", radiance),
  ("invitation-to-devas", "Invitation to the Devas", "An open listening pavilion beneath a quiet sky", "ink", invitation),
  ("buddha-virtues", "Virtues of the Buddha", "A bodhi leaf encircled by nine points", "paper", buddha_virtues),
  ("dhamma-virtues", "Virtues of the Dhamma", "Six palm-leaf manuscript strips", "paper", dhamma_virtues),
  ("sangha-virtues", "Virtues of the Sangha", "Nine robe-like forms in a shared assembly", "teal", sangha_virtues),
  ("net-of-virtues", "The Net of Virtues", "An interwoven protective field and nine golden nodes", "paper", virtues_net),
  ("sambuddhe", "Sambuddhe", "A gathering of lotus forms across successive terraces", "teal", many_buddhas),
  ("sivali", "Venerable Sivali", "A traveller's parasol, bowl and leaves", "paper", sivali),
  ("mangala", "Mangala Sutta", "Lotuses along a rising stair", "paper", mangala),
  ("ratana", "Ratana Sutta", "Three luminous faceted jewels", "paper", ratana),
  ("metta", "Metta Sutta", "A sheltering tree and a lotus beneath its canopy", "paper", metta_tree),
  ("khanda", "Khanda Sutta", "A peaceful serpent encircling a leaf", "paper", khanda),
  ("mora", "Mora Sutta", "A golden peacock and a sun at the horizon", "paper", mora),
  ("vatta", "Vatta Sutta", "A young quail in a quiet refuge beyond the flames", "rust", vatta),
  ("dhajagga", "Dhajagga Sutta", "A raised banner above distant mountains", "paper", dhajagga),
  ("atanatiya", "Atanatiya Sutta", "Four directional gateways surrounding a lotus", "paper", atanatiya),
  ("angulimala", "Angulimala Sutta", "A new leaf cradled inside a sheltering arch", "paper", angulimala),
  ("bojjhanga", "Bojjhanga Sutta", "Seven leaves along a growing branch", "teal", bojjhanga),
  ("pubbanha", "Pubbanha Sutta", "Morning light above still water", "rust", pubbanha),
  ("maccharaja", "Maccharaja Sutta", "A fish beneath rain and replenished water", "ink", maccha),
  ("mahasamaya", "Mahasamaya Sutta", "An assembly gathering around a central lotus", "ink", mahasamaya),
  ("dhammacakka", "Dhammacakka Sutta", "An eight-spoked wheel set in motion", "paper", dhammacakka),
  ("anattalakkhana", "Anattalakkhana Sutta", "Five open layers dispersing without a solid core", "paper", anatta),
  ("patthana-short", "Patthana · Abridged", "A small field of interdependent nodes", "paper", lambda: patthana(False)),
  ("patthana-full", "Patthana · Full", "Twenty-four linked points surrounding a jewel", "ink", lambda: patthana(True)),
  ("metta-ten-directions", "Metta in Ten Directions", "Eight outward rays with an above-and-below pair", "teal", ten_directions),
  ("metta-practice", "Metta · Cultivation", "Kindness spreading outward from a lotus", "ink", metta_practice),
]

# Explicit filenames keep motifs bound to the right prayer when a category is
# reordered. Never zip artwork to manifest positions: IDs and filenames are
# separate namespaces, and a reorder should change only contact-sheet order.
PRAYER_FILES = [
  'သြကာသ', 'သရဏဂုံ', 'သီလတောင်း', 'ငါးပါးသီလ', 'ရှစ်ပါးသီလ', 'ဆယ်ပါးသီလ',
  'အမျှဝေ', 'စိန်ရောင်ခြည်', 'နတ်ပင့်', 'ဘုရားဂုဏ်တော်', 'တရားဂုဏ်တော်',
  'သံဃာဂုဏ်တော်', 'ဂုဏ်တော်ကွန်ချာ', 'သမ္ဗုဒ္ဓေ', 'ရှင်သီဝလိ', 'မင်္ဂလသုတ်',
  'ရတနသုတ်', 'မေတ္တသုတ်', 'ခန္ဓသုတ်', 'မောရသုတ်', 'ဝဋ္ဋသုတ်', 'ဓဇဂ္ဂသုတ်',
  'အာဋာနာဋိယသုတ်', 'အင်္ဂုလိမာလသုတ်', 'ဗောဇ္ဈင်္ဂသုတ်', 'ပုဗ္ဗဏှသုတ်',
  'မစ္ဆရာဇသုတ်', 'မဟာသမယသုတ်', 'ဓမ္မစကြာသုတ်', 'အနတ္တလက္ခဏသုတ်',
  'ပဋ္ဌာန်းအကျဥ်း', 'ပဋ္ဌာန်းအကျယ်', 'ဆယ်မျက်နှာမ္မေတ္တာပွား', 'မေတ္တာသုတ်လာမ္မေတ္တာပွား',
]


def svg_document(slug, title, description, background, art):
  return (f'<svg xmlns="http://www.w3.org/2000/svg" width="800" height="800" viewBox="0 0 800 800" role="img" aria-labelledby="title-{slug} desc-{slug}">\n'
    f'<title id="title-{slug}">{escape(title)}</title>\n'
    f'<desc id="desc-{slug}">{escape(description)}. Original flat-colour vector illustration for PhayarSar.</desc>\n'
    f'<defs><clipPath id="crop-{slug}"><rect x="24" y="24" width="752" height="752"/></clipPath></defs>\n'
    + rect(0, 0, 800, 800, "paper") + '\n'
    + f'<g clip-path="url(#crop-{slug})">\n' + rect(24, 24, 752, 752, background) + '\n'
    + art + '\n</g>\n</svg>\n')


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--render', action='store_true', help='Render the contact sheet and validate all covers with rsvg-convert')
  args = parser.parse_args()
  taxonomy = json.loads((PRAYERS / 'manifest.json').read_text())
  prayers = [(category['id'], entry['file'], entry['cover'], json.loads((PRAYERS / (entry['file']+'.json')).read_text())) for category in taxonomy['categories'] for entry in category['prayers']]
  designs_by_name = dict(zip(PRAYER_FILES, DESIGNS, strict=True))
  if set(name for _, name, _, _ in prayers) != set(designs_by_name):
    raise ValueError('Catalog changed: assign a composition to every prayer before regenerating.')
  OUT.mkdir(parents=True, exist_ok=True)
  (OUT / 'svg').mkdir(exist_ok=True)
  ASSETS.mkdir(parents=True, exist_ok=True)
  (ASSETS / 'Contents.json').write_text(json.dumps(dict(info=dict(author='xcode', version=1)), indent=2)+'\n')
  records, documents = [], []
  for i, (category, name, asset_name, prayer) in enumerate(prayers, 1):
    slug, label, motif, bg, make = designs_by_name[name]
    document = svg_document(slug, prayer['title'], motif, bg, make())
    ET.fromstring(document)
    filename = f'{slug}.svg'
    (OUT / 'svg' / filename).write_text(document)
    image_set = ASSETS / (asset_name+'.imageset')
    image_set.mkdir(exist_ok=True)
    (image_set / filename).write_text(document)
    (image_set / 'Contents.json').write_text(json.dumps({
      'images': [dict(filename=filename, idiom='universal')],
      'info': dict(author='xcode', version=1),
      'properties': {'preserves-vector-representation': True, 'template-rendering-intent': 'original'},
    }, indent=2)+'\n')
    records.append(dict(order=i, prayerID=prayer['id'], prayerFile=name+'.json', title=prayer['title'], category=category, label=label, motif=motif, assetName=asset_name, svg='svg/'+filename))
    documents.append(document)

  catalog = dict(version=1, viewBox=[0, 0, 800, 800], palette=C, covers=records)
  (OUT / 'catalog.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n')
  build_sheet(records, documents)
  build_gallery(records)
  if args.render:
    renderer = shutil.which('rsvg-convert')
    if not renderer:
      raise SystemExit('SVGs created. Install librsvg to render previews, or omit --render.')
    # Every original is rendered, including at thumbnail size, so malformed
    # geometry cannot hide behind a good-looking contact sheet alone.
    import tempfile
    with tempfile.TemporaryDirectory(prefix='phayarsar-covers-') as temp:
      for entry in records:
        for size in [64, 800]:
          subprocess.run([renderer, '-w', str(size), '-h', str(size), '-o', str(Path(temp) / f'{entry["order"]}-{size}.png'), str(OUT / entry['svg'])], check=True)
    subprocess.run([renderer, '-o', str(OUT / 'preview.png'), str(OUT / 'preview.svg')], check=True)
  archive = OUT.parent / 'PhayarSar-Prayer-Covers.zip'
  with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as bundle:
    for file in sorted(OUT.rglob('*')):
      if file.is_file():
        bundle.write(file, 'PrayerCovers/'+str(file.relative_to(OUT)))
  print(f'Created {len(records)} distinct SVG covers, catalog, gallery, contact sheet and {archive.name}.')


def build_sheet(records, documents):
  cols, cell, gap, left, top = 6, 222, 22, 44, 177
  rows = math.ceil(len(records)/cols)
  width, height = left*2+cols*cell+(cols-1)*gap, top+rows*290+50
  sheet = f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">'
  sheet += rect(0, 0, width, height, '#EEE9DD')
  sheet += f'<g fill="{C["ink"]}" font-family="Helvetica, Arial, sans-serif"><text x="44" y="65" font-size="16" letter-spacing="4">PHAYARSAR / PRAYER COVER COLLECTION</text><text x="41" y="118" font-size="41" font-weight="bold">Thirty-four moments of stillness.</text><text x="44" y="150" font-size="16">Original SVG artwork · Flat inks · Square format · Catalog order</text></g>'
  for i, (entry, document) in enumerate(zip(records, documents)):
    x, y = left+(i%cols)*(cell+gap), top+(i//cols)*290
    root_start = document.index('>')+1
    inner = document[root_start:document.rfind('</svg>')]
    sheet += f'<svg x="{x}" y="{y}" width="{cell}" height="{cell}" viewBox="0 0 800 800">{inner}</svg>'
    sheet += f'<text x="{x+5}" y="{y+246}" font-family="Helvetica, Arial, sans-serif" font-size="13" fill="{C["ink"]}">{i+1:02d} / {escape(entry["label"])}</text>'
    sheet += f'<text x="{x+5}" y="{y+267}" font-family="Helvetica, Arial, sans-serif" font-size="11" letter-spacing="1.5" fill="{C["teal"]}">{entry["category"].upper()}</text>'
  sheet += '</svg>'
  ET.fromstring(sheet)
  (OUT / 'preview.svg').write_text(sheet)


def build_gallery(records):
  # Standalone review artifact: direct SVG links also work offline, with no
  # JavaScript, dependencies, server or remote font requests.
  cards = '\n'.join(f'<figure><a href="{r["svg"]}"><img src="{r["svg"]}" alt="{escape(r["motif"])}" loading="lazy"></a><figcaption><span>{r["order"]:02d} / {escape(r["label"])}</span><strong lang="my">{escape(r["title"])}</strong><p>{escape(r["motif"])}</p><a href="{r["svg"]}" download>Download SVG ↗</a></figcaption></figure>' for r in records)
  (OUT / 'index.html').write_text('''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>PhayarSar — Prayer Covers</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#eee9dd;color:#182f32;font:16px/1.5 system-ui,sans-serif}header,main,footer{max-width:1440px;margin:auto;padding:36px}header{padding-top:64px}header small{letter-spacing:.2em;font-size:12px}h1{font:clamp(36px,5vw,64px)/1.1 Georgia,serif;max-width:820px;margin:24px 0}header p{max-width:650px;color:#346963}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(235px,1fr));gap:36px 24px}figure{margin:0;min-width:0}img{width:100%;aspect-ratio:1;display:block}figcaption{padding:16px 7px}figcaption span{font-size:12px;text-transform:uppercase;letter-spacing:.05em}strong{display:block;font-size:19px;line-height:1.9;margin:8px 0}figcaption p{font-size:14px;min-height:42px;color:#346963}a{color:inherit;text-underline-offset:4px;font-size:13px}footer{border-top:1px solid #c5c6b7;font-size:13px}
</style><header><small>PHAYARSAR / ARTWORK COLLECTION</small><h1>Thirty-four moments<br>of stillness.</h1><p>Abstract prayer covers in a restrained retro palette. Each illustration is a fully editable square SVG, composed from flat vector shapes. Select any cover to inspect it at full size.</p><a href="preview.png">View the whole collection ↗</a></header><main>'''+cards+'''</main><footer>Artwork order and prayer IDs are recorded in <a href="catalog.json">catalog.json</a>. Motifs are artistic interpretations of the bundled prayers, not prescribed religious emblems.</footer></html>''')


if __name__ == '__main__':
  main()
