# 캐릭터 초상화 작업 지시서 (Codex용)

Codex에게 "tools/portrait_jobs.md 읽고 그대로 해 줘"라고 하면 이 문서대로 그린다.
그림 모델이 영어 지시를 더 잘 따르므로 지시 본문은 영어로 쓴다.

## Instructions for Codex

Generate one portrait image per character below with `$imagegen`, one image per call.
Save each image as `assets/portraits/<id>.png` (square, 1024x1024 is fine).
Skip any character whose `assets/portraits/<id>.jpg` or `<id>.png` already exists.
Do not edit any other file. When finished, list the files you created.

### Shared style (add to every prompt)

Semi-realistic painted digital illustration, like the character card art of a premium
historical strategy mobile game. Waist-up portrait, square 1:1 composition, the character
fills most of the frame. Rich detailed painterly rendering, dramatic warm cinematic lighting,
a detailed background that fits the character (blurred slightly behind them).
Every character must have a distinct face, pose, camera angle and gesture.
No text, no letters, no logos, no frame or border, no watermark.
Original design: do not imitate any existing game, film, anime or comic character design.

### Characters

| id | prompt |
|---|---|
| choichiwon | Choe Chiwon, Silla-era Korean scholar-poet, middle-aged, thin beard, black scholar's hat and blue official robe, writing calligraphy with a brush beside a misty mountain pavilion, calm thoughtful expression, three-quarter view facing left |
| libai | Li Bai, Tang dynasty Chinese poet, free-spirited, loose white and pale-green robes, raising a wine cup toward the full moon on a riverside terrace at night, flowing hair and beard, joyful expression, seen slightly from below |
| marcopolo | Marco Polo, 13th-century Venetian merchant traveler, young adult, short beard, red velvet travel coat and fur-trimmed cap, holding an unrolled map, silk-road caravan and camels in a desert behind him, curious smile, three-quarter view facing right |
| hypatia | Hypatia of Alexandria, ancient Greek mathematician and philosopher woman, dark hair tied up, white and blue chiton, holding an astrolabe, scroll shelves of a great library behind her, wise focused expression, front view |
| seohui | Seo Hui, Goryeo-dynasty Korean diplomat, middle-aged, neat beard, dark red Goryeo official robe and black official hat, one hand raised mid-speech at a negotiation tent with banners, confident composed expression, three-quarter view facing left |
| wukong | The Monkey King Sun Wukong from Journey to the West, monkey face with golden fur, golden phoenix-feather headband, red and gold armor, spinning a long red-and-gold iron staff, standing on a swirling cloud above mountains, mischievous grin, dynamic tilted angle; original design based on Chinese opera costume |
| dangun | Dangun, legendary founder of ancient Korea, dignified elderly king, long white beard, simple ancient white robes with bronze ornaments, bronze mirror and bronze sword, sacred altar on a mountain peak at sunrise, serene expression, front view slightly from below |
| athena | Athena, Greek goddess of wisdom and war, tall warrior woman, crested bronze Corinthian helmet pushed up, gleaming armor over a white peplos, round shield with an owl emblem and a spear, an owl on her shoulder, marble temple behind, stern noble expression, three-quarter view facing right |
| heracles | Heracles, Greek mythological hero, very muscular bearded man, wearing a lion-skin cloak with the lion's head as a hood, holding a huge wooden club over his shoulder, rocky landscape at sunset, fierce confident expression, three-quarter view facing left |
| gumiho | Gumiho, the nine-tailed fox of Korean folklore, beautiful woman in a white and pale-pink hanbok, nine glowing white fox tails fanned behind her, faint fox ears, golden eyes, a blue fox-fire orb floating in her palm, moonlit bamboo forest, mysterious smile, fully clothed and elegant |
| anubis | Anubis, ancient Egyptian god, black jackal head on a muscular human body, gold and lapis-lazuli collar and armbands, holding a was-scepter, golden scales of judgment beside him, dim torch-lit tomb with hieroglyphs, solemn expression, side three-quarter view |
| dokkaebi | Dokkaebi, a Korean folklore goblin, big friendly brute with a single horn, wild hair, broad grin, wearing a rough traditional Korean vest, holding a magic spiked wooden club that spills gold coins, night village with paper lanterns, playful expression, seen slightly from above |
| haetae | Haetae, the mythical Korean lion-like guardian beast, scaled body with a curly mane and a single horn, carved-stone and bronze colors coming to life, sitting proudly in front of a Joseon palace gate, glowing eyes, majestic expression, three-quarter view facing right |
| perseus | Perseus, Greek mythological hero, young man with curly hair, winged helmet and winged sandals, holding a polished mirror-like bronze shield and a curved sword, stormy sea cliffs behind, determined expression, front view; no severed head, no gore |
| tengu | Tengu, a Japanese mountain spirit, red-faced long-nosed yamabushi monk with large black feathered wings, small black cap, holding a feather fan, standing on a misty cedar-forest mountain, stern expression, three-quarter view facing left |
| isis | Isis, ancient Egyptian goddess, elegant woman with outstretched rainbow-feathered wings, golden vulture crown with a throne emblem, white linen dress and gold jewelry, holding an ankh, Nile river and temple at dusk, gentle protective expression, front view |
| tesla | Nikola Tesla, late-19th-century inventor, tall thin man, slicked dark hair and moustache, dark three-piece suit, sitting calmly while giant electric arcs from a tesla coil crackle around his lab, intense gaze, three-quarter view facing right |
| nightingale | Florence Nightingale, Victorian-era nurse, woman in a dark dress with a white apron and white cap, holding an oil lamp, walking through a dim military hospital ward at night, compassionate expression, three-quarter view facing left |
| edison | Thomas Edison, 1880s American inventor, middle-aged, short grey-brown hair, waistcoat with rolled-up sleeves, holding up a glowing light bulb, workshop full of wires and phonographs, pleased smile, front view |
| wright | The Wright brothers, two early-1900s American aviation pioneers standing side by side, flat caps and suits, one holding a wooden propeller, a fragile biplane on windy sand dunes behind them, hopeful expressions |
| amundsen | Roald Amundsen, Norwegian polar explorer, weathered face with a moustache, fur parka hood and snow goggles pushed up, holding a ski pole, sled dogs and a flag on the white Antarctic ice behind him, determined expression, three-quarter view facing right |
| verne | Jules Verne, 19th-century French science-fiction writer, white full beard, dark frock coat, writing at a desk with a quill while a submarine, a hot-air balloon and a moon cannon appear like a dream in the background, wondering expression |
| pasteur | Louis Pasteur, 19th-century French scientist, short beard, dark suit, holding up a swan-neck glass flask to the light in a laboratory full of glassware and microscopes, careful focused expression, three-quarter view facing left |
| houdini | Harry Houdini, early-1900s escape artist, short dark hair, wrapped in chains with a padlock, smirking confidently on a theater stage under a spotlight with red curtains, three-quarter view facing right |
| earhart | Amelia Earhart, 1930s American aviator woman, short wavy hair, leather flight jacket and scarf, goggles on her forehead, leaning on the propeller of a silver monoplane at an airfield at sunrise, bold smile |
| twain | Mark Twain, 19th-century American writer, white bushy hair and moustache, white suit, holding a pipe on the deck of a Mississippi riverboat with a paddle wheel, wry amused expression, three-quarter view facing left |
| fabre | Jean-Henri Fabre, French naturalist, elderly man with a wide-brimmed black hat, kneeling in a sunny garden studying insects through a magnifying glass, a beetle and a butterfly nearby, gentle curious expression, seen slightly from above |
| bangjeonghwan | Bang Jeong-hwan, 1920s Korean children's author, young man with neat short hair and round glasses, Korean traditional coat over a shirt, reading a storybook aloud with a warm smile, colorful kites and a schoolyard in the background, three-quarter view facing right |
