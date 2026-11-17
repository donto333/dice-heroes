"""영웅 음성 대사 번역(영어·베트남어). python tools/voice_i18n_src.py → data/voice_i18n.json
줄마다 "연기 지시(영어) | 영어 대사 | 베트남어 대사". 순서: select idle move attack defend skill win lose.
연기 지시는 두 언어가 함께 쓴다(v3 모델에 [지시]로 붙인다)."""
import json

KINDS = ["select", "idle", "move", "attack", "defend", "skill", "win", "lose"]

T = {
"lubu": """arrogant, deep | Who under heaven dares to stop me? Step forward, if you have the nerve. | Thiên hạ này ai dám cản ta? Có gan thì bước ra đây.
bored, scoffing | Hmph. My blood is restless. Where is the fight? | Hừ, tay chân ngứa ngáy quá. Bao giờ mới đánh?
shouting | Out of my way! I'm coming through! | Tránh đường! Ta đến đây!
roaring | Take my halberd! Haaah! | Đỡ lấy kích của ta! Hây!
mocking laugh | Ha! Is that all you've got? | Ha ha! Chỉ có vậy thôi sao?
roaring on the battlefield | Behold! The might of the peerless warrior! | Hãy nhìn đây! Sức mạnh vô song của ta!
laughing heartily | Hahaha! No one under heaven can match me! | Ha ha ha! Thiên hạ không ai địch nổi ta!
gritting teeth | Ugh... I will not forget this humiliation. | Hự... Mối nhục này ta sẽ không quên.""",
"yisunsin": """calm and dignified | I still have twelve ships left. | Thần vẫn còn mười hai chiến thuyền.
quietly thoughtful | First, we must read the wind and the tides. | Trước hết phải xem gió và dòng nước.
firm | All forces, advance. | Toàn quân, tiến lên.
commanding | Now! Fire all at once! | Ngay bây giờ! Bắn đồng loạt!
unwavering | Do not retreat. Hold the formation! | Không được lùi. Giữ vững đội hình!
commanding loudly | Crane wing formation! Surround the enemy! | Bày trận cánh hạc! Bao vây quân địch!
calm but moved | We won because we all fought together. | Đó là nhờ tất cả cùng chiến đấu.
solemn, low | Those who seek death shall live. I will rise again. | Quyết tử thì sẽ sống. Ta sẽ đứng dậy.""",
"alexander": """confident | I will see the end of the world with my own eyes. | Ta sẽ tận mắt nhìn thấy tận cùng thế giới.
gazing far away | There must be kingdoms beyond that horizon too. | Bên kia chân trời chắc cũng có những vương quốc.
energetic | Advance! Do not stop! | Tiến lên! Không được dừng!
spirited shout | Clear the way before my sword! | Hãy mở đường trước lưỡi kiếm của ta!
proud | A king does not retreat! | Vua không bao giờ lùi bước!
rallying an army | Conquer! The world is ours! | Chinh phục! Thế giới là của chúng ta!
satisfied | Another land shall remember my name. | Thêm một vùng đất sẽ nhớ tên ta.
graceful in defeat | Well done... I shall remember your name. | Giỏi lắm... Ta sẽ nhớ tên ngươi.""",
"machao": """bold and fiery | The golden general of the west rides out! | Mã Siêu của Tây Lương xuất trận đây!
restless | My horse wants to run. So do I. | Ngựa của ta muốn phi. Ta cũng vậy.
spurring a horse | Ride! Hyah! | Phi nào! Giá!
thrusting a spear | Take the spear of the west! | Đỡ lấy ngọn giáo Tây Lương!
gritting teeth | Is that all? I'll take it! | Chừng này thôi à? Ta đỡ được!
fierce | You won't escape! Chase them to the end! | Không thoát được đâu! Đuổi theo đến cùng!
young and hearty | Ha! Victory to the western cavalry! | Ha! Kỵ binh Tây Lương chiến thắng!
frustrated | Not yet... It's not over yet! | Chưa đâu... Vẫn chưa kết thúc!""",
"eulji": """relaxed and seasoned | I know these rivers better than anyone. | Dòng sông này ta hiểu rõ hơn ai hết.
stroking his beard | Waiting for the enemy to tire is also strategy. | Chờ địch mệt mỏi cũng là binh pháp.
calm | The time has come. Let us move. | Đã đến lúc. Chúng ta đi thôi.
sharp | I see an opening! Now! | Thấy sơ hở rồi! Ngay bây giờ!
steadfast | I will not give a single step. | Ta không lùi một bước nào.
triumphant command | You fell for the trap! Break the dam! | Trúng kế rồi! Phá đê đi!
chuckling politely | Heh heh. Be content with this and go home. | Ha ha, biết đủ thì hãy quay về đi.
calm sigh | Hmm, you read my move. | Hừm, ta bị đọc vị mất rồi.""",
"leonidas": """deep and firm | Not one step further shall you pass. | Không ai được bước qua con đường này.
low mutter | Polish your shields. The battle is near. | Lau sạch khiên đi. Sắp đến trận chiến rồi.
short and strong | Sparta, forward! | Sparta, tiến lên!
roaring | Take my spear! Hah! | Đỡ lấy giáo của ta! Hây!
holding the line | Shields up! Hold! | Giơ khiên lên! Trụ vững!
roaring to warriors | Do not retreat! We are the wall! | Không được lùi! Chúng ta là bức tường thành!
breathing hard | Did you see? This is Sparta! | Thấy chưa? Đây là Sparta!
falling but defiant | Even as I fall... I will not drop my shield. | Dù ngã xuống... ta không buông khiên.""",
"hanxin": """calm and confident | The more soldiers, the better. | Binh lính càng nhiều càng tốt.
thoughtful | A battle is won before it begins. | Trận thắng đã được định trước khi bắt đầu.
measured | Step by step, in order. | Từng bước một, theo thứ tự.
decisive | Now! Push them hard! | Ngay bây giờ! Dồn ép chúng!
unbothered | Just as I expected. | Đúng như ta dự đoán.
commanding loudly | Fight with the river at our backs! There is no retreat! | Bày trận bối thủy! Không còn đường lùi!
quiet smile | All according to plan. | Mọi thứ đúng như kế sách.
bitter | My plan was shallow. I must rethink it. | Kế của ta còn nông cạn. Phải tính lại.""",
"ganning": """cocky and boisterous | Hear the bells? The great Gan Ning has arrived! | Nghe tiếng chuông không? Cam Ninh ta đến rồi!
restless | Ugh, I'm itching for a fight! | Chà, ngứa ngáy chịu không nổi!
excited | Alright, let's have some fun! | Nào, quậy một trận thôi!
rough shout | Take this! Hyaah! | Ăn một đòn này! Hây!
scoffing | You call that an attack? | Thế mà gọi là tấn công à?
cocky shout | No rest! Here comes another! | Không nghỉ đâu! Tiếp chiêu nữa!
roaring laughter | Hahaha! The wine will taste great tonight! | Ha ha ha! Tối nay rượu sẽ ngon lắm đây!
grumbling | Tch, just bad luck today. | Chậc, hôm nay chỉ xui thôi.""",
"choiyoung": """solemn and deep | Look upon gold as you would a stone. | Hãy coi vàng như đá.
heavy | Only when the nation is at peace may a general rest. | Nước yên thì tướng mới được nghỉ.
firm | Follow me. | Theo ta.
commanding | Cut them down! | Chém chúng!
steadfast | I shall be the shield! | Ta sẽ là tấm khiên!
loud command | Raise an iron wall! Let no one through! | Dựng tường sắt! Không cho ai lọt qua!
dignified | The people can sleep in peace tonight. | Bá tánh đêm nay có thể ngủ yên rồi.
sorrowful | It is my own failing... | Đó là lỗi của ta...""",
"robinhood": """playful | Robin Hood, finest archer of Sherwood Forest. | Ta là Robin Hood, cung thủ giỏi nhất rừng Sherwood.
lighthearted | Whose purse will be heavy today, I wonder? | Hôm nay túi ai sẽ nặng đây nhỉ?
breezy | I know these woods. Follow me! | Ta rành đường rừng này. Theo ta!
drawing a bow | One arrow is all it takes! | Một mũi tên là đủ!
laughing | Whoa, that was close! | Ối, suýt nữa thì trúng!
cheeky | I'll just borrow this. It's for the poor! | Ta mượn tạm cái này nhé. Phần của người nghèo!
excited | Bullseye! Tonight we feast! | Trúng đích! Tối nay ăn mừng!
sheepish | Haha... even arrows miss sometimes. | Ha ha... cũng có ngày tên bắn trượt.""",
"mulan": """determined | I will fight in my father's place. | Con sẽ thay cha ra trận.
calm, catching breath | I'll polish my sword and wait for the moment. | Ta sẽ lau kiếm và chờ thời cơ.
brave and bright | All right, moving forward! | Được rồi, tiến lên!
battle cry | I won't back down! Hyah! | Ta không lùi bước! Hây!
gritting teeth | This won't knock me down! | Chừng này không quật ngã được ta!
shouting with strength | I'll rise again, as many times as it takes! | Dù bao nhiêu lần, ta cũng sẽ đứng dậy!
happy and bright | We did it! Is everyone safe? | Làm được rồi! Mọi người đều an toàn chứ?
frustrated but resolute | So frustrating... but next time, I'll win. | Tức quá... nhưng lần sau ta nhất định thắng.""",
"gyebaek": """solemn, low | There is no going back. This is where we stand. | Không còn đường lui. Đây là chỗ của chúng ta.
quietly | The wind on the plains is cold. | Gió trên cánh đồng lạnh quá.
resolute | Men of the last stand, forward. | Đội cảm tử, tiến lên.
all-out shout | Strike with your lives on the line! | Liều mạng mà chém!
holding firm | I will not retreat until I die! | Chưa chết thì ta chưa lùi!
menacing | Stand back! Come closer and I'll cut you down! | Lùi lại! Đến gần là ta chém!
catching breath | We held the line... again today. | Hôm nay... vẫn giữ được.
grieving | Is this the end... I fought without shame. | Đến đây thôi sao... Ta đã chiến đấu không hổ thẹn.""",
"sejong": """kind and noble | For my people, I will do anything. | Vì bá tánh, ta sẽ làm bất cứ điều gì.
calm, reading | The night is deep. Just a little more reading. | Đêm đã khuya. Đọc thêm chút nữa rồi ngủ.
gentle | Let us go together. | Chúng ta cùng đi nào.
firm but gentle | What is wrong must be set right! | Điều sai trái phải được sửa lại!
calm | Do not rush. There is always a way. | Đừng vội. Luôn có cách.
proclaiming | Write the voice of the people in letters of their own! | Hãy viết tiếng nói của bá tánh thành chữ!
pleased | This is thanks to everyone's wisdom. | Đó là nhờ trí tuệ của mọi người.
humble | I should have looked more carefully. | Lẽ ra trẫm phải xem xét kỹ hơn.""",
"zhugeliang": """calm and refined | The Sleeping Dragon has awakened. Shall I share my plan for the realm? | Ngọa Long đã tỉnh. Ngài có muốn nghe kế sách thiên hạ?
serene | The stars are moving strangely. | Các vì sao chuyển động bất thường.
calm | The wind has changed. Let us go. | Gió đã đổi chiều. Đi thôi.
quiet but sharp | You are already in the palm of my hand. | Ngươi đã nằm trong lòng bàn tay ta.
smiling | I read that move long ago. | Nước đi đó ta đã đọc từ lâu.
majestic | I shall deploy the Eight Trigrams. There is no way out. | Ta sẽ bày Bát Trận Đồ. Không có lối thoát.
calm | Everything went according to plan. | Mọi việc đều theo kế sách.
sighing | Heaven is not on our side... | Trời không giúp ta...""",
"davinci": """curious old man | The world is full of wonders. | Thế giới đầy những điều thú vị.
muttering | How do birds fly... Hmm, I must draw it again. | Chim bay thế nào nhỉ... Hừm, phải vẽ lại.
excited | Let's go and see for ourselves! | Nào, đi xem tận mắt thôi!
thrilled | What do you think of this design? | Thiết kế này thế nào!
calm | I prepared for that already. | Ta đã chuẩn bị sẵn rồi.
confident | Behold the blueprints in my mind! | Hãy xem bản thiết kế trong đầu ta!
delighted | Splendid! It worked just as I imagined! | Tuyệt vời! Chạy đúng như ta nghĩ!
disappointed | Hmm, I must revise the drawings. | Hừm, phải sửa lại bản vẽ.""",
"zhouyu": """elegant and confident | The southeast wind is blowing. Our time has come. | Gió đông nam đã thổi. Thời cơ đã đến.
playing a zither | If the melody is wrong, I always notice. | Nhạc sai một nốt, ta đều nhận ra.
light | Let us ride the river wind. | Theo gió sông mà đi.
sharp | Set the fire! | Phóng hỏa!
cold laugh | You thought such a trick would fool me? | Mưu mẹo đó mà định lừa ta sao?
commanding | Throw them into chaos! Shake their ranks! | Gây rối loạn! Làm rung chuyển trận địch!
triumphant | Never underestimate Zhou Yu of Jiangdong. | Đừng xem thường Chu Du của Giang Đông.
lamenting | Why does heaven test me so... | Sao trời lại thử thách ta thế này...""",
"jangyeongsil": """earnest and bright | Let me measure the time of the heavens. | Để tôi đo thời gian của bầu trời.
focused | If I file this gear just a bit more... | Mài bánh răng này thêm chút nữa là được...
eager | Yes, I'll go right away! | Vâng, tôi đi ngay!
confident | Behold the power of this device! | Hãy xem sức mạnh của thiết bị này!
calm | I already accounted for that. | Điều đó tôi đã tính trước rồi.
proud | Knowledge is power! The answer was in the books! | Hiểu biết là sức mạnh! Đáp án nằm trong sách!
overjoyed | I did it! The water clock rings its bell! | Thành công rồi! Đồng hồ nước đã điểm chuông!
downcast | My calculation was wrong. I'll build it again. | Tôi tính sai rồi. Tôi sẽ làm lại.""",
"archimedes": """excited old man | Eureka! I've found it, I've found it! | Eureka! Tìm ra rồi, tìm ra rồi!
muttering | Don't step on my circles... I'm calculating. | Đừng giẫm lên hình tròn của ta... ta đang tính.
relaxed | Give me a lever and I can go anywhere. | Có đòn bẩy thì đi đâu cũng được.
shouting | Take this! The power of principle! | Đỡ lấy! Sức mạnh của nguyên lý!
calm | You can't break through at that angle. | Góc đó không xuyên qua được đâu.
firm | The principle of the iron wall! Force must scatter! | Nguyên lý tường sắt! Lực sẽ bị phân tán!
laughing | Ha, proof complete! | Ha, chứng minh xong!
scratching head | Heh, I set up the equation wrong. | Ha ha, ta lập sai phương trình rồi.""",
"sunwu": """low and weighty | The best victory is won without fighting. | Không đánh mà thắng mới là thượng sách.
quiet | Know your enemy and yourself, and you will never be in peril. | Biết người biết ta, trăm trận không nguy.
calm | Let us move like flowing water. | Hãy di chuyển như dòng nước.
firm | Strike where they are empty! | Đánh vào chỗ trống!
calm | Defend firmly and you will not waver. | Giữ vững thì không lay chuyển.
quiet but strong | All warfare is deception. The ruse worked! | Binh bất yếm trá. Kế đã thành công!
calm | I won before I fought. | Thắng trước rồi mới đánh.
calm | I did not know my enemy well enough. | Ta chưa hiểu hết kẻ địch.""",
"choichiwon": """scholarly and calm | With a single line of writing, I will move the world. | Chỉ với một dòng chữ, ta sẽ lay chuyển thế gian.
reciting poetry | In the autumn wind, I chant in sorrow... | Trong gió thu, ta buồn bã ngâm thơ...
dignified | Shall I take up my brush and set out? | Cầm bút lên đường thôi.
emphatic | These words are my sword! | Những dòng chữ này là thanh kiếm của ta!
steadfast | Righteous words do not break. | Lời chính trực không thể bị bẻ gãy.
clear declaration | The power of learning! Time to use what I know! | Sức mạnh của học vấn! Đến lúc thể hiện rồi!
pleased | My words moved their hearts. | Lời văn đã lay động lòng người.
lonely | Few in this world understand me. | Thế gian ít ai hiểu ta.""",
"libai": """tipsy and merry | A cup beneath the moon, and a poem. What do you say? | Một chén dưới trăng, một bài thơ thì sao?
drowsy | Hmm... out of wine. But the moon is still bright. | Hừm... hết rượu rồi. Trăng vẫn còn sáng.
humming, swaying | Let's go wherever the wind blows. | Gió thổi đâu thì đi đó.
hearty | Swords and poems are best when drunk! | Kiếm hay thơ, say mới ngon!
laughing | Oops! A drunk man is hard to hit. | Ối! Người say khó bị đánh trúng lắm.
grand recitation | Blow, O wind! Follow me, O clouds! | Gió ơi thổi đi! Mây ơi theo ta!
laughing heartily | Hahaha! Another cup for this feeling! | Ha ha ha! Thêm một chén nữa nào!
disappointed | Ah, I've sobered up. | Ôi, tỉnh rượu mất rồi.""",
"marcopolo": """excited storyteller | The East holds so many wonders. | Phương Đông có biết bao điều kỳ diệu.
reminiscing | I remember the sunset over the Silk Road. | Tôi nhớ hoàng hôn trên Con đường Tơ lụa.
cheerful | Let's set off to find a new road! | Nào, lên đường tìm lối mới!
confident | Witness the skill of a seasoned traveler! | Hãy xem tài của người đi xa!
relaxed | Danger like this was common on the road. | Nguy hiểm thế này trên đường là chuyện thường.
confident shout | Navigate by the stars! Set the course! | Nhìn sao định hướng! Giữ vững hải trình!
delighted | I must write this story in my book! | Chuyện này phải viết vào sách mới được!
calm | The way home is also a journey. | Đường về cũng là một chuyến đi.""",
"hypatia": """intellectual and calm | Shall we read the paths of the stars together? | Chúng ta cùng đọc đường đi của các vì sao nhé?
quiet | Never stop asking questions. That is learning. | Không ngừng đặt câu hỏi, đó là học.
calm | Just follow the orbit. | Cứ đi theo quỹ đạo là được.
decisive | The answer is already clear! | Đáp án đã rõ rồi!
calm | That equation is wrong. | Phương trình đó sai rồi.
quiet and mysterious | Forget it all. Think again from the beginning. | Quên hết đi. Hãy suy nghĩ lại từ đầu.
gentle smile | Reason has won. | Lý trí đã chiến thắng.
wistful | There was still something I didn't know. | Vẫn còn điều ta chưa biết.""",
"seohui": """calm and confident | With words alone, I will defend this land. | Chỉ bằng lời nói, ta sẽ giữ mảnh đất này.
thoughtful | First, we must see what the other side wants. | Trước hết phải xem đối phương muốn gì.
calm | Let us go and negotiate. | Đi đàm phán thôi.
emphatic | That makes no sense at all! | Lời đó hoàn toàn vô lý!
steadfast | Not an inch of land will I give up. | Không nhường một tấc đất.
encouraging | Take heart! We are in the right! | Cố lên! Chúng ta đúng!
dignified | We won without drawing a sword. | Thắng mà không cần rút kiếm.
calm | My words were not enough. | Lời ta chưa đủ thuyết phục.""",
"zeus": """majestic, godlike | I am Zeus, king of thunder. Bow your head. | Ta là Zeus, vua sấm sét. Hãy cúi đầu.
slow and imposing | No need to hurry. The heavens always wait. | Không cần vội. Bầu trời luôn chờ đợi.
commanding | Follow me, mortals. | Theo ta, hỡi người phàm.
furious shout | Face the judgment of the gods! | Hãy nhận sự phán xét của thần linh!
angry | You dare lay a hand on a god? | Ngươi dám động vào thần sao?
shouting like thunder | Lightning! Strike them down! | Sấm sét! Giáng xuống bọn chúng!
low laugh | Heh heh heh. Was there ever any doubt? | Hừ hừ hừ. Kết quả hiển nhiên thôi.
disbelieving | Impossible... I let my guard down. | Không thể nào... Ta đã sơ suất.""",
"wukong": """young, high and playful like a mischievous monkey | Here comes the Great Sage, Sun Wukong! | Tề Thiên Đại Thánh Tôn Ngộ Không giá đáo!
young, playful, yawning | Yawn, I'm bored. Maybe I'll grab a peach. | Ngáp, chán quá. Đi hái đào ăn thôi.
young, playful, excited | Riding my cloud! Whoosh! | Cưỡi cân đẩu vân đây! Vèo!
young, playful shout | Taste my staff! | Nếm thử gậy Như Ý của ta này!
young, giggling | Hehe, that was just my clone! | Hì hì, đó chỉ là phân thân của ta thôi!
young, loud and excited | Let's go, cloud! A hundred thousand miles! | Đi nào, cân đẩu vân! Mười vạn tám nghìn dặm!
young, smug | See? I'm the Great Sage! | Thấy chưa? Ta chính là Tề Thiên Đại Thánh!
young, grumbling | Tch, don't tell my master, okay? | Chậc, đừng nói với sư phụ nhé?""",
"dangun": """kind and majestic | Bring benefit to all humankind. | Hãy làm lợi ích cho muôn người.
serene | Do you remember the day the heavens opened? | Ngươi có nhớ ngày trời mở ra không?
gentle | Children, open the way. | Hỡi các con, hãy mở đường.
stern | Do not defy the will of heaven! | Đừng chống lại ý trời!
calm | That power cannot reach me. | Sức mạnh đó không chạm tới ta.
proclaiming to the sky | Let light shine upon the whole world! | Hãy ban ánh sáng cho khắp nhân gian!
warm | We achieved this together. | Chúng ta đã cùng nhau làm nên điều này.
calm | This too must be the will of heaven. | Đây cũng là ý trời.""",
"athena": """dignified and wise | Wisdom leads to victory. | Trí tuệ dẫn lối chiến thắng.
calm | Battles are won with the mind, not strength. | Trận chiến thắng bằng trí óc, không phải sức mạnh.
firm | Raise your spears. We go. | Giơ giáo lên. Xuất phát.
sharp shout | Take the spear of the goddess of war! | Đỡ lấy ngọn giáo của nữ thần chiến tranh!
cold | My shield does not break. | Khiên của ta không thể vỡ.
solemn blessing | I grant you my protection. Fight without fear. | Ta ban sự che chở. Hãy chiến đấu không sợ hãi.
graceful | Well fought. A wise victory. | Đánh hay lắm. Một chiến thắng sáng suốt.
dignified in defeat | This time... you were one step ahead. | Lần này... ngươi hơn ta một bậc.""",
"heracles": """hearty and deep | I finished twelve labors! Leave anything to me! | Ta đã hoàn thành mười hai kỳ công! Cứ giao cho ta!
bored | Lion or monster, anyone out there? | Sư tử hay quái vật, có ai không?
energetic | Alright, time to warm up! | Được rồi, khởi động nào!
roaring | Hrraaah! Take this! | Hây a! Đỡ này!
mocking laugh | Ha! That tickles! | Ha! Nhột quá!
huge roar | All-out attack! I'll smash a mountain! | Tấn công dữ dội! Ta sẽ đập nát cả núi!
laughing heartily | Hahaha! The thirteenth labor is done! | Ha ha ha! Kỳ công thứ mười ba cũng xong!
frustrated | Grr... beaten in strength? Impossible! | Hừ... thua về sức mạnh? Không thể nào!""",
"gumiho": """playful, teasing | Oh my, falling for me already? Hehe. | Ôi, đã phải lòng ta rồi sao? Hì hì.
lazy yawn | Haaah... so bored. Anyone I can charm today? | Haa... chán quá. Có ai để ta mê hoặc không nhỉ?
light and cheerful | Come on, follow me! | Nào, theo ta đi!
sharp laugh | Hehe, want a taste of my tails? | Hì hì, muốn nếm thử đuôi của ta không?
teasing | Oops, I'm not over there! | Ôi, ta đâu có ở đó!
whispering, then eerie | Shh... you'd better watch your back. | Suỵt... coi chừng sau lưng đấy.
giggling | Ahaha! Too easy! Wanna play again? | A ha ha! Dễ quá! Chơi thêm ván nữa nhé?
pouting | Hmph, I just went easy on you today. Really! | Hứ, hôm nay ta nhường thôi. Thật đấy!""",
"anubis": """low and ominous | The scales of the underworld await you. | Cán cân âm phủ đang chờ ngươi.
quiet | The sand falls, and time is on my side. | Cát rơi, và thời gian đứng về phía ta.
cold | Death is never in a hurry. | Cái chết không bao giờ vội vàng.
menacing | Let us weigh your heart! | Hãy cân trái tim ngươi!
icy | The strength of the living cannot reach me. | Sức mạnh người sống không chạm tới ta.
quiet then loud | Tremble. The gates of the underworld open! | Run sợ đi. Cổng âm phủ đã mở!
calm | The scales do not lie. | Cán cân không biết nói dối.
low | Not yet... your time has not come. | Chưa... chưa đến lượt ngươi.""",
"dokkaebi": """goofy and gravelly | Gold, come out! Silver, come out! Bonk! | Vàng ra đây! Bạc ra đây! Cốc!
cackling | Anyone up for a wrestling match? | Có ai muốn vật một trận không?
giggling | Heh heh, where shall I go? | Hê hê, đi đâu bây giờ nhỉ?
loud | Taste my club! Bonk! | Nếm gậy của ta này! Cốc!
teasing | Nyeh! That didn't hurt! | Lêu lêu, không đau đâu!
playful shout | Right back at you! Bonk! | Trả lại cho ngươi đây! Cốc!
laughing heartily | Ha ha! Bring me buckwheat jelly! | Ha ha! Mang thạch kiều mạch ra đây!
grumbling | Bah, I only lost because the sun came up! | Hừ, tại trời sáng nên ta mới thua!""",
"haetae": """heavy and stern | I guard against fire and disaster. | Ta ngăn chặn lửa và tai họa.
low | My horn tells right from wrong. | Sừng của ta phân biệt đúng sai.
deep | I go to guard the road. | Ta đi canh giữ con đường.
growling | The wicked shall be rammed! | Kẻ gian sẽ bị húc văng!
firm | None shall pass here. | Không ai được qua đây.
roaring | I hold! Disaster shall not take a single step inside! | Trụ vững! Tai họa không vào được một bước!
dignified | The palace is safe once again. | Cung điện hôm nay vẫn bình an.
low | I... could not stop it? | Ta... đã không ngăn được sao?""",
"perseus": """young and proud | I slew Medusa with my own hands. | Chính tay ta đã chém Medusa.
thoughtful | Sometimes you need a shield like a mirror. | Có lúc cần một tấm khiên như gương.
energetic | With winged sandals, away! | Với đôi dép có cánh, xuất phát!
shouting | Take this blade! | Đỡ lấy lưỡi kiếm này!
nimble | Look in my shield and I see everything! | Soi vào khiên là thấy hết!
brave shout | A keen blade! I can cut with my eyes closed! | Lưỡi kiếm sắc bén! Nhắm mắt cũng chém được!
happy | The monster has fallen! Let's go home! | Quái vật đã ngã! Về thôi!
frustrated | Oh no... I met its gaze. | Ôi không... ta lỡ nhìn vào mắt nó.""",
"tengu": """arrogant and low | Every wind on this mountain is mine. | Mọi cơn gió trên núi này là của ta.
scoffing | Why are humans so slow? | Sao loài người chậm chạp thế?
fast | Riding the wind! | Cưỡi gió mà đi!
fierce | Feel the wind of my fan! | Đỡ lấy gió quạt của ta!
mocking | Hmph, you thought you could reach me? | Hừ, tưởng chạm được ta sao?
loud | Charge! Strike like the mountain wind! | Xung phong! Ập tới như gió núi!
smug | See? This is the master of the mountain. | Thấy chưa, đây là chủ nhân của núi.
frustrated | Ugh, my pride is crushed... | Hự, ta bị bẽ mặt rồi...""",
"isis": """clear and caring | I give you the breath of life. | Ta trao cho ngươi hơi thở sự sống.
soft | I can hear the waters of the Nile. | Ta nghe thấy tiếng nước sông Nile.
gentle | Carefully now, let's go together. | Cẩn thận nhé, chúng ta cùng đi.
firm | That's enough. Step back now! | Đủ rồi. Lùi lại đi!
warm | It's all right, I'll protect you. | Không sao, ta sẽ bảo vệ ngươi.
praying warmly | A healing touch... let the wounds close. | Bàn tay chữa lành... vết thương hãy lành lại.
relieved | I'm so glad everyone is safe. | Mọi người đều bình an, thật may quá.
calm | It's all right. We just rise again. | Không sao. Đứng dậy là được.""",
"tesla": """cold and intellectual | The future is mine. | Tương lai thuộc về tôi.
musing | Alternating current flows through my mind. | Dòng điện xoay chiều đang chạy trong đầu tôi.
calm | Let us move as fast as current. | Hãy đi nhanh như dòng điện.
sharp | One million volts! | Một triệu vôn!
calm | I grounded that already. | Tôi đã nối đất từ trước rồi.
rising to a shout | Lightning coil, activate! Behold the power of the sky! | Cuộn dây sấm sét, khởi động! Hãy xem sức mạnh của bầu trời!
quietly satisfied | My calculations are never wrong. | Tính toán của tôi không bao giờ sai.
bitter | The world still cannot keep up with me. | Thế giới vẫn chưa theo kịp tôi.""",
"nightingale": """warm and firm | This lamp will never go out. | Ngọn đèn này sẽ không bao giờ tắt.
quiet | I should make my rounds of the ward tonight too. | Đêm nay tôi cũng phải đi một vòng phòng bệnh.
calm | Let's go where the wounded are. | Hãy đến chỗ người bị thương.
firm | Step away from the patient! | Tránh xa bệnh nhân ra!
resolute | As long as I'm here, no one gives up! | Còn tôi ở đây thì không ai bỏ cuộc!
encouraging | Everyone, get up! We can still do this! | Mọi người đứng dậy! Chúng ta vẫn làm được!
relieved | I'm glad everyone is safe. | Mọi người an toàn là tốt rồi.
sad but resolute | It hurts... but tomorrow I'll light the lamp again. | Buồn quá... nhưng ngày mai tôi vẫn sẽ thắp đèn.""",
"edison": """seasoned and stubborn | Fail a thousand times, succeed once, and that's enough. | Thất bại nghìn lần, thành công một lần là đủ.
muttering | Not this filament. Bring me the next one. | Không phải dây tóc này. Mang cái tiếp theo đây.
energetic | Come, let's step out of the lab! | Nào, ra khỏi phòng thí nghiệm thôi!
confident | Behold my latest invention! | Hãy xem phát minh mới của tôi!
unbothered | I already patented that. | Cái đó tôi đã đăng ký bằng sáng chế rồi.
proud | Invention complete! The light is on! | Phát minh hoàn tất! Đèn sáng rồi!
laughing | Ha, it worked on the thousand-and-first try! | Ha, lần thứ một nghìn lẻ một thì thành công!
matter-of-fact | I just found one more way that doesn't work. | Tôi chỉ tìm thêm một cách không hiệu quả thôi.""",
"wright": """excited and bright | Today we will fly for sure! | Hôm nay nhất định chúng ta sẽ bay!
checking the wind | Good wind... Brother, check the wings! | Gió tốt đấy... Anh ơi, xem cánh giúp em!
excited | Spin the propeller, let's go! | Quay cánh quạt, xuất phát!
shouting | Coming from above, watch out! | Từ trên cao đây, coi chừng!
relaxed | A little tilt and I can dodge it! | Nghiêng một chút là né được!
thrilled | Exploration flight! We're up, we're up! | Bay thám hiểm! Lên rồi, lên rồi!
cheering | We flew! We really flew! | Bay được rồi! Thật sự bay được rồi!
cheerful | It's fine, I'll fix the wings and fly again. | Không sao, sửa cánh rồi bay lại.""",
"amundsen": """calm and sturdy | I survived the cold of the South Pole. | Tôi đã vượt qua cái lạnh Nam Cực.
quiet | Preparation is victory. Let's check the sleds again. | Chuẩn bị là chiến thắng. Kiểm tra lại xe trượt nào.
measured | Step by step, to the very end. | Từng bước một, đến tận cùng.
firm | Break the ice and push on! | Phá băng mà tiến lên!
steadfast | I'm used to a blizzard or two. | Bão tuyết thì tôi quen rồi.
commanding | Set the course! Straight south! | Định hướng! Thẳng về phía nam!
holding back emotion | The flag is planted. We did it. | Cờ đã cắm. Chúng ta làm được rồi.
calm | Coming home alive is part of exploring too. | Sống sót trở về cũng là thám hiểm.""",
"verne": """gentle storyteller | What you imagine will someday come true. | Điều ta tưởng tượng rồi sẽ thành hiện thực.
dreamy | What lies twenty thousand leagues under the sea? | Hai vạn dặm dưới đáy biển có gì nhỉ?
excited | Around the world in eighty days! | Vòng quanh thế giới trong tám mươi ngày!
emphatic | Never underestimate imagination! | Đừng xem thường trí tưởng tượng!
relaxed | I already wrote that scene. | Cảnh đó tôi đã viết rồi.
cheerful | I read it in a book! The answer is in this chapter! | Tôi đọc trong sách rồi! Đáp án ở chương này!
pleased | A fine ending. Time to write the next volume. | Một kết thúc hay. Đi viết tập tiếp theo thôi.
wistful | I'll have to rewrite this chapter. | Chương này phải viết lại rồi.""",
"pasteur": """earnest and warm | I am fighting an enemy no eye can see. | Tôi đang chiến đấu với kẻ thù vô hình.
focused | Hmm, these tiny things spread disease. | Hừm, những thứ nhỏ bé này lây bệnh đây.
calm | No rush. Let's be precise. | Đừng vội, hãy chính xác.
firm | Begone, germs! | Vi trùng, lui ra!
calm | I boiled and sterilized it already. | Tôi đã đun sôi khử trùng rồi.
warm blessing | Bless you all. This vaccine will protect everyone. | Chúc phúc cho mọi người. Vắc xin này sẽ bảo vệ tất cả.
relieved | The child lived. That is enough. | Đứa bé đã sống. Vậy là đủ.
resolute | We can always run the experiment again. | Thí nghiệm thì làm lại là được.""",
"houdini": """showman, confident | No lock in the world can hold me! | Không ổ khóa nào giữ được tôi!
shuffling cards | Now, would you pick a card? | Nào, mời bạn rút một lá bài?
lively | Ladies and gentlemen, to the stage! | Thưa quý vị, lên sân khấu nào!
shouting | Blink and you'll miss it! Hup! | Chớp mắt là lỡ đấy! Hấp!
cheeky | Huh? I've already escaped. | Ơ? Tôi đã thoát ra rồi mà.
showman flourish | Ta-da! The wound vanishes without a trace! | Ta-đa! Vết thương biến mất không dấu vết!
bowing | A round of applause, please! Thank you! | Xin một tràng pháo tay! Cảm ơn!
sheepish | Haha... that was just a rehearsal. | Ha ha... đó chỉ là buổi tập thôi.""",
"earhart": """brave and bright | The sky has no limits. | Bầu trời không có giới hạn.
looking up | It must be clear above the clouds today. | Hôm nay trên mây chắc trời quang.
excited | Engine on, taking off! | Nổ máy rồi, cất cánh!
shouting | Nose dive, here I come! | Bổ nhào, lao xuống đây!
relaxed | I'm used to turbulence! | Nhiễu động thì tôi quen rồi!
energetic | Full throttle! Hold on tight! | Hết tốc lực! Bám chắc vào!
happy | Landing successful! What a flight! | Hạ cánh thành công! Chuyến bay tuyệt vời!
cheerful | Ran out of fuel. Next time I'll go farther. | Hết nhiên liệu rồi. Lần sau tôi sẽ bay xa hơn.""",
"twain": """wry storyteller | Want to hear a funny story? | Muốn nghe một chuyện vui không?
lazy | The Mississippi will flow slowly again today. | Hôm nay sông Mississippi lại trôi chầm chậm.
easygoing | Shall we drift along on a raft? | Thả bè trôi thong thả nhé?
witty | The pen stings more than the sword! | Ngòi bút còn đau hơn lưỡi kiếm!
deadpan | Reports of my defeat are greatly exaggerated. | Tin đồn tôi thua đã bị phóng đại quá rồi.
cheerful | Well, let's start over from the beginning! | Nào, bắt đầu lại từ đầu thôi!
laughing | Ha, this will make a good story. | Ha, chuyện này viết thành truyện hay đây.
wry | Well, losing stories are fun to write too. | Chà, chuyện thua viết ra cũng vui.""",
"fabre": """kind old man | Look closely at the little things. | Hãy nhìn kỹ những điều nhỏ bé.
whispering | Shh... a dung beetle is passing by. | Suỵt... bọ hung đang đi ngang qua.
slow | Slowly, watch your step. | Chậm thôi, nhìn dưới chân nhé.
emphatic | A bee's sting is small, but it smarts! | Nọc ong nhỏ nhưng đau lắm đấy!
calm | Just curl up tight like a beetle. | Cứ cuộn tròn chắc như con bọ.
firm | Hold tight. A shell doesn't break easily. | Giữ chắc vào. Vỏ không dễ vỡ đâu.
pleased | A good observation. I'll write it in my notebook. | Quan sát hay lắm. Phải ghi vào sổ.
calm | It's fine. We can look again tomorrow. | Không sao. Mai lại quan sát tiếp.""",
"bangjeonghwan": """kind and bright | Children are the hope of tomorrow. | Trẻ em là hy vọng của ngày mai.
warm | What story shall I tell the children today? | Hôm nay kể chuyện gì cho các em đây?
gentle | Let's hold hands and go together. | Nắm tay cùng đi nào.
firm | You must not make the children cry! | Không được làm các em khóc!
resolute | I'll stand in front! | Tôi sẽ đứng phía trước!
cheering | Everyone, cheer up! We can do it! | Mọi người cố lên! Chúng ta làm được!
happy | Everyone's smiling, so I'm happy too. | Mọi người cười nên tôi cũng vui.
comforting | It's okay. If you fall, just get back up. | Không sao. Ngã thì đứng dậy thôi.""",
}

# 안내 음성(문장 대사)·안내 음성 짧게(m)·적 음성
ANNOUNCER = {
 "en": {"start": "The game begins!", "turn": "It's your turn!", "enemy_turn": "Opponent's turn.", "battle": "Battle start!", "double": "Double!",
        "gate": "Gate battle!", "goal": "Goal!", "catchup": "Catch-up chance!", "last_turn": "Final turn!", "win": "Victory!", "lose": "Defeat."},
 "vi": {"start": "Trận đấu bắt đầu!", "turn": "Đến lượt bạn!", "enemy_turn": "Đến lượt đối thủ.", "battle": "Bắt đầu chiến đấu!", "double": "Đôi!",
        "gate": "Trận chiến cửa ải!", "goal": "Về đích!", "catchup": "Cơ hội bắt kịp!", "last_turn": "Lượt cuối cùng!", "win": "Chiến thắng!", "lose": "Thất bại."},
}
ANNOUNCER_SHORT = {
 "en": {"start": "Game start!", "turn": "My turn!", "enemy_turn": "Their turn!", "battle": "Battle!", "double": "Double!",
        "gate": "Gate battle!", "goal": "Goal!", "catchup": "Catch up!", "last_turn": "Last turn!", "win": "Win!", "lose": "Lose..."},
 "vi": {"start": "Bắt đầu!", "turn": "Lượt tôi!", "enemy_turn": "Lượt địch!", "battle": "Chiến đấu!", "double": "Đôi!",
        "gate": "Cửa ải!", "goal": "Về đích!", "catchup": "Bắt kịp!", "last_turn": "Lượt cuối!", "win": "Thắng!", "lose": "Thua..."},
}
ENEMY = {
 "enemy_gate": {"en": {"appear": "Halt! No one passes this gate!", "win": "Begone! And never come back!", "lose": "Ugh... very well, pass."},
                "vi": {"appear": "Dừng lại! Không ai được qua cửa ải này!", "win": "Cút đi! Đừng bao giờ quay lại!", "lose": "Hự... được rồi, qua đi."}},
 "enemy_boss": {"en": {"appear": "So you made it this far. But this is the end.", "win": "You're not ready. Come back stronger!", "lose": "Splendid... this match is yours."},
                "vi": {"appear": "Ngươi đến được tận đây sao. Nhưng đây là điểm cuối.", "win": "Còn non lắm. Mạnh hơn rồi hãy đến!", "lose": "Giỏi lắm... trận này ngươi thắng."}},
 "enemy_keeper": {"en": {"appear": "I guard this outpost. Come at me!", "win": "Hahaha! With skills like that?", "lose": "No way... I lost?"},
                  "vi": {"appear": "Ta canh giữ cứ điểm này. Lao vào đây!", "win": "Ha ha ha! Tài cán thế mà đòi à!", "lose": "Sao lại thế... ta thua ư?"}},
 "enemy_monster": {"en": {"appear": "Graaaah!", "win": "Kuhahaha!", "lose": "Gwaaagh..."},
                   "vi": {"appear": "Graaaah!", "win": "Kha kha kha!", "lose": "Grừ..."}},
}


def build() -> dict:
    out = {"_comment": "영웅·안내·적 음성 대사의 영어·베트남어 번역(tools/voice_i18n_src.py가 만든다). 소리 파일은 assets/audio/voice_<언어>/<id>_<상황>.ogg. 한국어 목소리 그대로 그 나라 말을 한다(사용자 결정 2026-11-17).",
           "tags": {}, "en": {}, "vi": {}}
    for hero_id, text in T.items():
        rows = [line.split(" | ") for line in text.strip().split("\n")]
        assert len(rows) == 8 and all(len(r) == 3 for r in rows), hero_id
        out["tags"][hero_id] = {k: r[0].strip() for k, r in zip(KINDS, rows)}
        out["en"][hero_id] = {k: r[1].strip() for k, r in zip(KINDS, rows)}
        out["vi"][hero_id] = {k: r[2].strip() for k, r in zip(KINDS, rows)}
    for lang in ("en", "vi"):
        for x in "lno":
            out[lang]["announcer_" + x] = ANNOUNCER[lang]
        out[lang]["announcer_m"] = ANNOUNCER_SHORT[lang]
        for enemy, table in ENEMY.items():
            out[lang][enemy] = table[lang]
    return out


if __name__ == "__main__":
    data = build()
    lines = json.load(open("data/voice_lines.json", encoding="utf-8"))
    assert set(data["en"]).issuperset(lines["heroes"].keys()), set(lines["heroes"]) - set(data["en"])
    json.dump(data, open("data/voice_i18n.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("영웅 %d명" % len(T))
