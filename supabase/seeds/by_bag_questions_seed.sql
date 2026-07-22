-- Red bag question bank: 200 middle-school ('ms', grades 6-8) + 200
-- high-school ('hs', everyone else) multiple-choice Bible questions.
-- One-time seed for by_bag_questions (applied to staging + prod
-- 2026-07-22). The guard below refuses to run against a non-empty bank
-- so it can never double-seed.

do $$ begin
  if (select count(*) from public.by_bag_questions) > 0 then
    raise exception 'by_bag_questions already seeded (% rows)',
      (select count(*) from public.by_bag_questions);
  end if;
end $$;

-- ============================================================
-- MIDDLE SCHOOL (200)
-- ============================================================

-- Creation & Genesis beginnings (20)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('ms', 'On which day did God create people?', '["Day 1","Day 3","Day 6","Day 7"]'::jsonb, 2),
('ms', 'What did God create on the very first day?', '["Animals","Light","Oceans","Stars"]'::jsonb, 1),
('ms', 'Who was the first woman?', '["Sarah","Ruth","Mary","Eve"]'::jsonb, 3),
('ms', 'What garden did Adam and Eve live in?', '["Eden","Gethsemane","Babylon","Canaan"]'::jsonb, 0),
('ms', 'Which creature tempted Eve to eat the fruit?', '["A lion","A serpent","A raven","A goat"]'::jsonb, 1),
('ms', 'Adam and Eve were told not to eat from the tree of the knowledge of good and what?', '["Life","Truth","Evil","Wisdom"]'::jsonb, 2),
('ms', 'Who was the first person ever to commit murder?', '["Lamech","Esau","Nimrod","Cain"]'::jsonb, 3),
('ms', 'Who did Cain kill?', '["Abel","Seth","Enoch","Noah"]'::jsonb, 0),
('ms', 'Who built the ark before the great flood?', '["Moses","Noah","Abraham","Adam"]'::jsonb, 1),
('ms', 'How many days and nights did it rain during the flood?', '["7","12","40","100"]'::jsonb, 2),
('ms', 'Which bird brought Noah an olive leaf?', '["A raven","An eagle","A sparrow","A dove"]'::jsonb, 3),
('ms', 'What sign did God give as a promise never to flood the whole earth again?', '["A rainbow","A star","A burning bush","A white dove"]'::jsonb, 0),
('ms', 'What tower did people build trying to reach the heavens?', '["Tower of Jericho","Tower of Babel","Tower of Siloam","Tower of David"]'::jsonb, 1),
('ms', 'What did God do at the Tower of Babel?', '["Sent a flood","Sent fire","Confused their languages","Knocked it down with wind"]'::jsonb, 2),
('ms', 'How many days did God spend creating before he rested?', '["3","5","10","6"]'::jsonb, 3),
('ms', 'On which day did God rest?', '["The seventh","The first","The third","The tenth"]'::jsonb, 0),
('ms', 'Which of these was one of Noah''s three sons?', '["Abram","Shem","Isaac","Levi"]'::jsonb, 1),
('ms', 'What did God use to make Adam?', '["Sea water","Starlight","Dust of the ground","A tree"]'::jsonb, 2),
('ms', 'What did God use to make Eve?', '["Clay","A flower","Adam''s hair","Adam''s rib"]'::jsonb, 3),
('ms', 'What guarded the way back into the Garden of Eden?', '["Cherubim with a flaming sword","A stone wall","Two lions","A great storm"]'::jsonb, 0);

-- Abraham, Isaac, Jacob, Joseph (20)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('ms', 'God promised Abraham descendants as numerous as what?', '["Grains of rice","The stars in the sky","Drops of rain","Leaves on trees"]'::jsonb, 1),
('ms', 'What was Abraham''s name before God changed it?', '["Abimelech","Aaron","Abram","Abner"]'::jsonb, 2),
('ms', 'Who was Abraham''s wife?', '["Rebekah","Rachel","Leah","Sarah"]'::jsonb, 3),
('ms', 'Which son was born to Abraham and Sarah when they were very old?', '["Isaac","Ishmael","Jacob","Esau"]'::jsonb, 0),
('ms', 'What did God provide on the mountain instead of Isaac?', '["A dove","A ram","A lamb from the flock","A bull"]'::jsonb, 1),
('ms', 'Who were Isaac''s twin sons?', '["Cain and Abel","Ephraim and Manasseh","Jacob and Esau","James and John"]'::jsonb, 2),
('ms', 'What did Esau trade away his birthright for?', '["A camel","Silver coins","A coat","A bowl of stew"]'::jsonb, 3),
('ms', 'What did Jacob see in his dream at Bethel?', '["A stairway to heaven","A burning bush","Seven cows","A giant statue"]'::jsonb, 0),
('ms', 'What new name did God give Jacob?', '["Judah","Israel","Levi","Benjamin"]'::jsonb, 1),
('ms', 'How many sons did Jacob have?', '["7","10","12","14"]'::jsonb, 2),
('ms', 'Which son received a beautiful colorful robe from his father?', '["Reuben","Judah","Benjamin","Joseph"]'::jsonb, 3),
('ms', 'Where was Joseph taken after his brothers sold him?', '["Egypt","Babylon","Canaan","Assyria"]'::jsonb, 0),
('ms', 'Who dreamed about seven fat cows and seven skinny cows?', '["Joseph","Pharaoh","Jacob","The baker"]'::jsonb, 1),
('ms', 'What did Pharaoh''s dream of the cows mean?', '["A war was coming","A flood was coming","Seven good years, then seven years of famine","Seven kings would rule"]'::jsonb, 2),
('ms', 'What position did Pharaoh give Joseph?', '["Chief baker","Army general","Palace guard","Second in command over Egypt"]'::jsonb, 3),
('ms', 'Lot''s wife became a pillar of salt when she looked back at what city?', '["Sodom","Nineveh","Jericho","Babel"]'::jsonb, 0),
('ms', 'Who was Isaac''s wife?', '["Rachel","Rebekah","Sarah","Dinah"]'::jsonb, 1),
('ms', 'Which brother suggested selling Joseph instead of killing him?', '["Simeon","Levi","Judah","Dan"]'::jsonb, 2),
('ms', 'In whose house did Joseph work as a slave in Egypt?', '["The king''s","The jailer''s","A merchant''s","Potiphar''s"]'::jsonb, 3),
('ms', 'Whose dreams did Joseph interpret while he was in prison?', '["The cupbearer''s and the baker''s","Two guards''","Pharaoh''s sons''","Two shepherds''"]'::jsonb, 0);

-- Moses & the Exodus (20)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('ms', 'In which river did baby Moses float in a basket?', '["The Jordan","The Nile","The Euphrates","The Red Sea"]'::jsonb, 1),
('ms', 'Who found baby Moses in the river?', '["A shepherd girl","His sister","Pharaoh''s daughter","The queen of Egypt"]'::jsonb, 2),
('ms', 'How did God first speak to Moses in the desert?', '["Through a dream","Through an angel with a sword","Through a dove","Through a burning bush"]'::jsonb, 3),
('ms', 'What message did God send to Pharaoh through Moses?', '["Let my people go","Build me a temple","Bring me gold","Leave Egypt forever"]'::jsonb, 0),
('ms', 'How many plagues did God send on Egypt?', '["7","10","12","40"]'::jsonb, 1),
('ms', 'What was the final plague on Egypt?', '["Locusts","Darkness","Death of the firstborn","Hail"]'::jsonb, 2),
('ms', 'At the first Passover, what did the Israelites put on their doorposts?', '["Olive branches","Written prayers","Gold marks","Lamb''s blood"]'::jsonb, 3),
('ms', 'Which sea did God part so Israel could escape?', '["The Red Sea","The Dead Sea","The Sea of Galilee","The Great Sea"]'::jsonb, 0),
('ms', 'What bread-like food did God send from heaven in the desert?', '["Figs","Manna","Barley","Honey cakes"]'::jsonb, 1),
('ms', 'On which mountain did Moses receive the Ten Commandments?', '["Mount Carmel","Mount Nebo","Mount Sinai","Mount Zion"]'::jsonb, 2),
('ms', 'How many commandments did God give Moses on the tablets?', '["5","7","12","10"]'::jsonb, 3),
('ms', 'What golden animal did the Israelites wrongly worship at the mountain?', '["A calf","A lion","An eagle","A serpent"]'::jsonb, 0),
('ms', 'Who was Moses'' brother?', '["Joshua","Aaron","Caleb","Eleazar"]'::jsonb, 1),
('ms', 'Who was Moses'' sister?', '["Deborah","Zipporah","Miriam","Hannah"]'::jsonb, 2),
('ms', 'What did Moses strike to bring out water in the desert?', '["The ground","A tree","The sand","A rock"]'::jsonb, 3),
('ms', 'How many years did Israel wander in the wilderness?', '["40","12","70","100"]'::jsonb, 0),
('ms', 'The first commandment says to have no other what before God?', '["Kings","Gods","Friends","Treasures"]'::jsonb, 1),
('ms', 'What guided the Israelites through the desert by day?', '["A star","An angel","A pillar of cloud","A golden eagle"]'::jsonb, 2),
('ms', 'What guided the Israelites through the desert by night?', '["A full moon","Torches","A glowing angel","A pillar of fire"]'::jsonb, 3),
('ms', 'What special tent did Israel build for worshiping God in the desert?', '["The tabernacle","The temple","The synagogue","The ark"]'::jsonb, 0);

-- Joshua, Judges, Ruth (15)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('ms', 'Who led Israel into the Promised Land after Moses died?', '["Aaron","Joshua","Caleb","Samuel"]'::jsonb, 1),
('ms', 'The walls of which city fell after Israel marched around it?', '["Ai","Bethel","Jericho","Hebron"]'::jsonb, 2),
('ms', 'How many times did Israel march around Jericho on the seventh day?', '["1","3","5","7"]'::jsonb, 3),
('ms', 'Who hid the Israelite spies in Jericho?', '["Rahab","Ruth","Esther","Deborah"]'::jsonb, 0),
('ms', 'What did the Israelites blow before the walls of Jericho fell?', '["Whistles","Trumpets","Flutes","Bells"]'::jsonb, 1),
('ms', 'Which judge''s great strength was connected to his uncut hair?', '["Gideon","Ehud","Samson","Jephthah"]'::jsonb, 2),
('ms', 'Who tricked Samson into revealing the secret of his strength?', '["Jezebel","Ruth","Michal","Delilah"]'::jsonb, 3),
('ms', 'What animal did Samson tear apart with his bare hands?', '["A lion","A bear","A wolf","A wild ox"]'::jsonb, 0),
('ms', 'Which judge defeated a huge army with only 300 men?', '["Samson","Gideon","Barak","Othniel"]'::jsonb, 1),
('ms', 'What did Gideon''s 300 men carry into battle?', '["Swords and shields","Bows and arrows","Trumpets and torches in jars","Spears and slings"]'::jsonb, 2),
('ms', 'Who was the woman judge who led Israel to victory?', '["Miriam","Hannah","Naomi","Deborah"]'::jsonb, 3),
('ms', 'Ruth famously stayed loyal to whom?', '["Naomi","Orpah","Boaz","Her father"]'::jsonb, 0),
('ms', 'In whose field did Ruth gather leftover grain?', '["Obed''s","Boaz''s","Jesse''s","Laban''s"]'::jsonb, 1),
('ms', 'Ruth became the great-grandmother of which king?', '["Saul","Solomon","David","Hezekiah"]'::jsonb, 2),
('ms', 'What did Gideon lay out at night to ask God for a sign?', '["A robe","A basket of bread","A lamb","A wool fleece"]'::jsonb, 3);

-- David, Saul, Solomon & the kings (20)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('ms', 'Who was Israel''s first king?', '["Saul","David","Solomon","Samuel"]'::jsonb, 0),
('ms', 'Which prophet anointed both Saul and David as king?', '["Elijah","Samuel","Nathan","Elisha"]'::jsonb, 1),
('ms', 'What giant did young David defeat?', '["Og","Anak","Goliath","Nimrod"]'::jsonb, 2),
('ms', 'What did David use to defeat the giant?', '["A sword","A spear","A bow","A sling and a stone"]'::jsonb, 3),
('ms', 'What instrument did David play to calm King Saul?', '["A harp","A drum","A trumpet","A flute"]'::jsonb, 0),
('ms', 'Who was David''s closest friend?', '["Absalom","Jonathan","Joab","Nathan"]'::jsonb, 1),
('ms', 'David wrote many songs found in which book of the Bible?', '["Proverbs","Lamentations","Psalms","Ecclesiastes"]'::jsonb, 2),
('ms', 'Which of David''s sons became known as the wisest king?', '["Absalom","Adonijah","Amnon","Solomon"]'::jsonb, 3),
('ms', 'When God offered Solomon anything, what did Solomon ask for?', '["Wisdom","Riches","Long life","Victory in battle"]'::jsonb, 0),
('ms', 'What great building did Solomon build in Jerusalem?', '["A palace of cedar","The temple","The city walls","A tower"]'::jsonb, 1),
('ms', 'When two women both claimed one baby, what did Solomon suggest to find the true mother?', '["Asking the baby","Casting lots","Dividing the baby in two","A week with each woman"]'::jsonb, 2),
('ms', 'What was David''s job before he became king?', '["Carpenter","Fisherman","Soldier","Shepherd"]'::jsonb, 3),
('ms', 'What town was David from?', '["Bethlehem","Jerusalem","Nazareth","Hebron"]'::jsonb, 0),
('ms', 'Which queen traveled far to test Solomon''s wisdom?', '["Queen Esther","The Queen of Sheba","Queen Jezebel","The Queen of Egypt"]'::jsonb, 1),
('ms', 'After Solomon died, the kingdom split into Judah and what?', '["Edom","Moab","Israel","Assyria"]'::jsonb, 2),
('ms', 'Which young king found the lost Book of the Law and turned Judah back to God?', '["Ahab","Jeroboam","Manasseh","Josiah"]'::jsonb, 3),
('ms', 'Which boy heard God calling his name at night while serving with Eli?', '["Samuel","David","Solomon","Obed"]'::jsonb, 0),
('ms', 'Goliath was a champion of which people?', '["The Amalekites","The Philistines","The Moabites","The Egyptians"]'::jsonb, 1),
('ms', 'How many smooth stones did David pick up before facing Goliath?', '["1","3","5","7"]'::jsonb, 2),
('ms', 'Who was the wicked queen married to King Ahab?', '["Athaliah","Herodias","Vashti","Jezebel"]'::jsonb, 3);

-- Daniel, Jonah, Esther, Elijah (20)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('ms', 'Where was Daniel thrown for praying to God?', '["A lions'' den","A fiery furnace","A deep well","A prison tower"]'::jsonb, 0),
('ms', 'Which three friends of Daniel were thrown into the fiery furnace?', '["Peter, James, and John","Shadrach, Meshach, and Abednego","Shem, Ham, and Japheth","Eliab, Abinadab, and Shammah"]'::jsonb, 1),
('ms', 'The king looked into the furnace and saw how many men walking around?', '["2","3","4","5"]'::jsonb, 2),
('ms', 'At Belshazzar''s feast, where did the mysterious writing appear?', '["On a scroll","In the sky","On the floor","On the wall"]'::jsonb, 3),
('ms', 'What did Daniel choose to eat instead of the king''s rich food?', '["Vegetables and water","Bread and fish","Meat and milk","Fruit and honey"]'::jsonb, 0),
('ms', 'What swallowed Jonah?', '["A whale-sized crocodile","A great fish","A sea serpent","A giant turtle"]'::jsonb, 1),
('ms', 'How long was Jonah inside the great fish?', '["One day","Seven days","Three days and three nights","Forty days"]'::jsonb, 2),
('ms', 'To which city did God tell Jonah to go and preach?', '["Babylon","Jericho","Damascus","Nineveh"]'::jsonb, 3),
('ms', 'Instead of obeying, Jonah sailed toward which place?', '["Tarshish","Egypt","Cyprus","Joppa"]'::jsonb, 0),
('ms', 'What grew up to shade Jonah and then withered?', '["A fig tree","A leafy plant","An olive tree","A grape vine"]'::jsonb, 1),
('ms', 'Which brave queen saved the Jewish people from destruction?', '["Ruth","Deborah","Esther","Abigail"]'::jsonb, 2),
('ms', 'Who was Esther''s older cousin who raised her?', '["Haman","Xerxes","Nehemiah","Mordecai"]'::jsonb, 3),
('ms', 'Who plotted to destroy all the Jews in the book of Esther?', '["Haman","Sanballat","Nebuchadnezzar","Belshazzar"]'::jsonb, 0),
('ms', 'Which prophet challenged the prophets of Baal to a contest?', '["Elisha","Elijah","Isaiah","Micah"]'::jsonb, 1),
('ms', 'On which mountain did Elijah face the prophets of Baal?', '["Mount Sinai","Mount Zion","Mount Carmel","Mount Hermon"]'::jsonb, 2),
('ms', 'What fell from heaven and burned up Elijah''s sacrifice?', '["Lightning only","A whirlwind","Burning hail","Fire"]'::jsonb, 3),
('ms', 'What birds brought Elijah food by the brook?', '["Ravens","Doves","Eagles","Sparrows"]'::jsonb, 0),
('ms', 'How did Elijah leave the earth?', '["He fell asleep on a mountain","In a whirlwind with a chariot of fire","He walked into the sea","No one knows where he went"]'::jsonb, 1),
('ms', 'Who became prophet after Elijah?', '["Samuel","Nathan","Elisha","Amos"]'::jsonb, 2),
('ms', 'Naaman was healed of leprosy by washing seven times in which river?', '["The Nile","The Euphrates","The Kishon","The Jordan"]'::jsonb, 3);

-- Bible basics (15)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('ms', 'How many books are in the whole Bible?', '["66","72","50","39"]'::jsonb, 0),
('ms', 'How many books are in the Old Testament?', '["27","39","44","66"]'::jsonb, 1),
('ms', 'How many books are in the New Testament?', '["39","12","27","33"]'::jsonb, 2),
('ms', 'What is the first book of the Bible?', '["Exodus","Psalms","Matthew","Genesis"]'::jsonb, 3),
('ms', 'What is the last book of the Bible?', '["Revelation","Malachi","Jude","Acts"]'::jsonb, 0),
('ms', 'The first four books of the New Testament are called what?', '["The Letters","The Gospels","The Prophets","The Chronicles"]'::jsonb, 1),
('ms', 'Which of these is one of the four Gospels?', '["Acts","Romans","Luke","James"]'::jsonb, 2),
('ms', 'Which book of the Bible has the most chapters?', '["Genesis","Isaiah","Proverbs","Psalms"]'::jsonb, 3),
('ms', 'The verse "Jesus wept" is found in which Gospel?', '["John","Matthew","Mark","Luke"]'::jsonb, 0),
('ms', 'What are the two main sections of the Bible called?', '["The Law and the Prophets","The Old and New Testaments","The Gospels and the Letters","The Psalms and the Proverbs"]'::jsonb, 1),
('ms', 'Which book comes right after the four Gospels?', '["Romans","Revelation","Acts","Hebrews"]'::jsonb, 2),
('ms', 'Psalm 23 begins, "The Lord is my..."', '["rock","light","king","shepherd"]'::jsonb, 3),
('ms', 'Psalm 119 says God''s word is a lamp to my what?', '["feet","heart","home","hands"]'::jsonb, 0),
('ms', 'Which book is full of short wise sayings?', '["Numbers","Proverbs","Judges","Ezra"]'::jsonb, 1),
('ms', 'Most of the Old Testament was first written in which language?', '["Greek","Latin","Hebrew","English"]'::jsonb, 2);

-- Jesus' birth & early life (15)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('ms', 'In what town was Jesus born?', '["Nazareth","Jerusalem","Capernaum","Bethlehem"]'::jsonb, 3),
('ms', 'Who was Jesus'' mother?', '["Mary","Elizabeth","Martha","Anna"]'::jsonb, 0),
('ms', 'Who was Jesus'' earthly father?', '["Zechariah","Joseph","Simeon","Jacob"]'::jsonb, 1),
('ms', 'Which angel told Mary she would have a son?', '["Michael","Raphael","Gabriel","Uriel"]'::jsonb, 2),
('ms', 'Where was baby Jesus laid after he was born?', '["A basket","A wooden bed","A blanket on the floor","A manger"]'::jsonb, 3),
('ms', 'Who followed a star to find young Jesus?', '["The wise men","The shepherds","The priests","The fishermen"]'::jsonb, 0),
('ms', 'Which of these was one of the wise men''s three gifts?', '["Silver","Frankincense","Pearls","Silk"]'::jsonb, 1),
('ms', 'Which king tried to kill baby Jesus?', '["Caesar","Pilate","Herod","Nebuchadnezzar"]'::jsonb, 2),
('ms', 'Where did Joseph and Mary flee to protect baby Jesus?', '["Babylon","Rome","Damascus","Egypt"]'::jsonb, 3),
('ms', 'Who visited Jesus on the night he was born, after angels told them?', '["Shepherds","Kings","Fishermen","Soldiers"]'::jsonb, 0),
('ms', 'In what town did Jesus grow up?', '["Bethlehem","Nazareth","Jericho","Cana"]'::jsonb, 1),
('ms', 'At age 12, where did Mary and Joseph find Jesus after searching?', '["At the market","By the sea","In the temple","At a wedding"]'::jsonb, 2),
('ms', 'Who baptized Jesus?', '["Peter","Andrew","Nicodemus","John the Baptist"]'::jsonb, 3),
('ms', 'In which river was Jesus baptized?', '["The Jordan","The Nile","The Euphrates","The Tigris"]'::jsonb, 0),
('ms', 'What descended on Jesus like a dove at his baptism?', '["An angel","The Holy Spirit","A bright cloud","A white robe"]'::jsonb, 1);

-- Jesus' miracles (20)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('ms', 'What was Jesus'' first miracle?', '["Walking on water","Healing a blind man","Turning water into wine","Feeding 5,000"]'::jsonb, 2),
('ms', 'At what kind of event did Jesus turn water into wine?', '["A festival","A funeral","A birthday","A wedding"]'::jsonb, 3),
('ms', 'Jesus fed 5,000 people with five loaves and how many fish?', '["Two","Five","Seven","Twelve"]'::jsonb, 0),
('ms', 'How many baskets of leftovers were collected after feeding the 5,000?', '["3","12","7","40"]'::jsonb, 1),
('ms', 'What did Jesus walk on to reach his disciples'' boat?', '["A bridge","A sandbar","Water","Stepping stones"]'::jsonb, 2),
('ms', 'Which disciple stepped out of the boat and walked on water toward Jesus?', '["John","James","Andrew","Peter"]'::jsonb, 3),
('ms', 'What did Jesus calm with the words "Peace, be still"?', '["A storm","An angry crowd","A roaring lion","A fire"]'::jsonb, 0),
('ms', 'Who did Jesus raise from the dead after four days in the tomb?', '["Jairus","Lazarus","Stephen","Timothy"]'::jsonb, 1),
('ms', 'Who were Lazarus'' two sisters?', '["Ruth and Naomi","Elizabeth and Anna","Mary and Martha","Joanna and Susanna"]'::jsonb, 2),
('ms', 'What did Jesus put on the eyes of a man born blind?', '["Water","Oil","A cloth","Mud"]'::jsonb, 3),
('ms', 'How did the paralyzed man''s friends get him to Jesus in a crowded house?', '["Through a hole in the roof","Through a window","They waited outside","They shouted over the crowd"]'::jsonb, 0),
('ms', 'Jesus healed ten men with leprosy — how many came back to say thank you?', '["Ten","One","Five","None"]'::jsonb, 1),
('ms', 'A sick woman was healed when she touched what?', '["Jesus'' hand","Jesus'' sandal","The edge of Jesus'' robe","Jesus'' staff"]'::jsonb, 2),
('ms', 'Jesus raised the young daughter of which synagogue leader?', '["Nicodemus","Zacchaeus","Simon","Jairus"]'::jsonb, 3),
('ms', 'Where did Peter find a coin to pay the temple tax?', '["In a fish''s mouth","On the road","In his boat","In a bird''s nest"]'::jsonb, 0),
('ms', 'What happened to the fig tree that Jesus said would never bear fruit again?', '["It grew taller","It withered","It fell over","It bloomed"]'::jsonb, 1),
('ms', 'Whose ear did Jesus heal after Peter cut it off?', '["A Roman soldier''s","Judas''","The high priest''s servant''s","A temple guard captain''s"]'::jsonb, 2),
('ms', 'Jesus sent a legion of demons out of a man and into what animals?', '["Goats","Camels","Sheep","Pigs"]'::jsonb, 3),
('ms', 'What did blind Bartimaeus receive from Jesus?', '["His sight","Gold coins","New sandals","Bread"]'::jsonb, 0),
('ms', 'The Roman centurion said Jesus didn''t need to come to his house — Jesus only needed to do what?', '["Send a disciple","Say the word","Write a letter","Pray all night"]'::jsonb, 1);

-- Jesus' parables & teaching (15)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('ms', 'The Good Samaritan helped a hurt man on the road to which city?', '["Bethany","Nazareth","Jericho","Damascus"]'::jsonb, 2),
('ms', 'What did the father do when the prodigal son came home?', '["Sent him away","Made him a servant","Ignored him","Ran to hug him and threw a feast"]'::jsonb, 3),
('ms', 'The shepherd left how many sheep to search for the one lost sheep?', '["99","100","50","12"]'::jsonb, 0),
('ms', 'The wise man built his house on what?', '["Sand","Rock","A hill","Clay"]'::jsonb, 1),
('ms', 'The foolish man built his house on what?', '["Grass","Mud","Sand","Gravel"]'::jsonb, 2),
('ms', 'In the parable of the sower, seed that fell on good soil produced what?', '["Nothing","Weeds","Thorns","A huge harvest"]'::jsonb, 3),
('ms', 'Jesus said faith like a tiny mustard seed can grow into what?', '["A great tree","A river","A mountain","A city"]'::jsonb, 0),
('ms', 'What prayer did Jesus teach his disciples?', '["The Shepherd''s Prayer","The Lord''s Prayer","The Temple Prayer","The Morning Prayer"]'::jsonb, 1),
('ms', 'Jesus said to love your neighbor as you love what?', '["Your family","Your friends","Yourself","Your church"]'::jsonb, 2),
('ms', 'Jesus gave his most famous sermon on a what?', '["Boat","Beach","Rooftop","Mountainside"]'::jsonb, 3),
('ms', 'What did the shepherd do when he found his lost sheep?', '["Carried it home rejoicing","Scolded it","Sold it","Left it in the field"]'::jsonb, 0),
('ms', 'In Jesus'' parable, the woman with ten silver coins lost how many?', '["Five","One","Two","Ten"]'::jsonb, 1),
('ms', 'What did the merchant do when he found the pearl of great price?', '["Stole it","Ignored it","Sold everything he had to buy it","Split it with a friend"]'::jsonb, 2),
('ms', 'In the parable of the talents, what did the fearful servant do with his money?', '["Invested it","Spent it","Gave it away","Buried it in the ground"]'::jsonb, 3),
('ms', 'In the Good Samaritan story, who walked past the hurt man first?', '["A priest and a Levite","Two soldiers","Two tax collectors","A king and a judge"]'::jsonb, 0);

-- Holy Week, death & resurrection (10)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('ms', 'What animal did Jesus ride into Jerusalem?', '["A horse","A donkey","A camel","A mule cart"]'::jsonb, 1),
('ms', 'What did the crowds wave and lay on the road as Jesus entered Jerusalem?', '["Flags","Flowers","Palm branches","Wheat stalks"]'::jsonb, 2),
('ms', 'What meal did Jesus share with his disciples before his arrest?', '["The Passover feast at Cana","A breakfast by the sea","A wedding feast","The Last Supper"]'::jsonb, 3),
('ms', 'Which disciple betrayed Jesus?', '["Judas","Thomas","Philip","Bartholomew"]'::jsonb, 0),
('ms', 'How many pieces of silver was Judas paid?', '["12","30","50","100"]'::jsonb, 1),
('ms', 'In what garden did Jesus pray the night he was arrested?', '["Eden","The king''s garden","Gethsemane","The temple garden"]'::jsonb, 2),
('ms', 'Which disciple denied knowing Jesus three times?', '["John","James","Andrew","Peter"]'::jsonb, 3),
('ms', 'What crowed after Peter''s third denial?', '["A rooster","A dove","A raven","An owl"]'::jsonb, 0),
('ms', 'On which day did Jesus rise from the dead?', '["The seventh day","The third day","The fortieth day","The tenth day"]'::jsonb, 1),
('ms', 'Who discovered that Jesus'' tomb was empty?', '["Roman guards","The priests","Women who came to the tomb","Pilate"]'::jsonb, 2);

-- Disciples & the early church (10)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('ms', 'How many disciples did Jesus choose?', '["7","10","12","70"]'::jsonb, 2),
('ms', 'Which disciple was a tax collector before following Jesus?', '["Peter","John","Philip","Matthew"]'::jsonb, 3),
('ms', 'Which disciple doubted the resurrection until he saw Jesus himself?', '["Thomas","Andrew","James","Simon"]'::jsonb, 0),
('ms', 'Peter''s brother, also a disciple, was named what?', '["Philip","Andrew","Thaddaeus","Levi"]'::jsonb, 1),
('ms', 'What came upon the believers at Pentecost?', '["A great flood","An earthquake","The Holy Spirit","A famine"]'::jsonb, 2),
('ms', 'Saul saw a blinding light on the road to which city?', '["Rome","Antioch","Jerusalem","Damascus"]'::jsonb, 3),
('ms', 'What name was Saul known by after he began following Jesus?', '["Paul","Silas","Timothy","Barnabas"]'::jsonb, 0),
('ms', 'Who was the first follower of Jesus to be killed for his faith?', '["James","Stephen","Peter","Mark"]'::jsonb, 1),
('ms', 'Who helped Peter escape from prison in the night?', '["Paul","A Roman guard","An angel","John"]'::jsonb, 2),
('ms', 'Philip explained the book of Isaiah to an official from which land?', '["Rome","Greece","Persia","Ethiopia"]'::jsonb, 3);

-- ============================================================
-- HIGH SCHOOL (200)
-- ============================================================

-- Pentateuch deeper (20)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('hs', 'Melchizedek, who blessed Abraham, was king of Salem and also a what?', '["Priest of God Most High","Prophet of Israel","Judge of Canaan","Shepherd of Midian"]'::jsonb, 0),
('hs', 'What sign did God give Abraham to mark his covenant?', '["A rainbow","Circumcision","A stone altar","A dove"]'::jsonb, 1),
('hs', 'What did Jacob name the place where he wrestled with God until daybreak?', '["Bethel","Shechem","Peniel","Gilgal"]'::jsonb, 2),
('hs', 'Which two spies believed Israel could take the Promised Land?', '["Moses and Aaron","Eleazar and Phinehas","Dathan and Abiram","Joshua and Caleb"]'::jsonb, 3),
('hs', 'Which tribe of Israel was set apart to serve as priests?', '["Levi","Judah","Benjamin","Reuben"]'::jsonb, 0),
('hs', 'On the Day of Atonement, where was the scapegoat sent?', '["Into the temple","Into the wilderness","Across the Jordan","Into Egypt"]'::jsonb, 1),
('hs', 'The Shema — "Hear, O Israel: The LORD our God, the LORD is one" — is found in which book?', '["Genesis","Leviticus","Deuteronomy","Numbers"]'::jsonb, 2),
('hs', 'The prophet Balaam was famously rebuked by what?', '["An angel with a scroll","A talking raven","A burning tree","His own donkey"]'::jsonb, 3),
('hs', 'What happened to Aaron''s staff to prove God chose him as priest?', '["It budded and produced almonds","It turned to gold","It became a serpent forever","It split a rock"]'::jsonb, 0),
('hs', 'Nadab and Abihu, Aaron''s sons, died because they offered what?', '["A blemished lamb","Unauthorized fire before the LORD","Stolen grain","A pagan idol"]'::jsonb, 1),
('hs', 'What was kept inside the ark of the covenant?', '["Aaron''s robes","The bronze serpent","The stone tablets of the law","Torah scrolls"]'::jsonb, 2),
('hs', 'Why was Moses not allowed to enter the Promised Land?', '["He killed an Egyptian","He broke the tablets","He doubted the spies","He struck the rock instead of speaking to it"]'::jsonb, 3),
('hs', 'From which mountain did Moses view the Promised Land before he died?', '["Mount Nebo","Mount Sinai","Mount Hor","Mount Carmel"]'::jsonb, 0),
('hs', 'Israelites bitten by snakes were healed by doing what?', '["Washing in the Jordan","Looking at the bronze serpent","Eating manna","Touching the ark"]'::jsonb, 1),
('hs', 'Which feast celebrates Israel''s deliverance from Egypt?', '["Pentecost","Tabernacles","Passover","Purim"]'::jsonb, 2),
('hs', 'The Year of Jubilee came every how many years?', '["7","10","100","50"]'::jsonb, 3),
('hs', 'The cities of refuge protected people who had done what?', '["Killed someone accidentally","Stolen from the temple","Fled from slavery","Broken the Sabbath"]'::jsonb, 0),
('hs', 'Who were Joseph''s two sons, later counted among Israel''s tribes?', '["Perez and Zerah","Ephraim and Manasseh","Er and Onan","Gershom and Eliezer"]'::jsonb, 1),
('hs', 'What does the word "Genesis" mean?', '["Covenant","Creation story","Beginning","The law"]'::jsonb, 2),
('hs', 'The Passover lamb had to be a male without what?', '["A mother","Horns","Wool","Blemish"]'::jsonb, 3);

-- Old Testament history deeper (20)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('hs', 'Achan''s hidden sin caused Israel''s defeat at which city?', '["Ai","Gibeon","Hazor","Lachish"]'::jsonb, 0),
('hs', 'During whose battle did the sun stand still?', '["Gideon''s","Joshua''s","David''s","Saul''s"]'::jsonb, 1),
('hs', 'Which left-handed judge killed King Eglon of Moab?', '["Shamgar","Othniel","Ehud","Tola"]'::jsonb, 2),
('hs', 'Which judge made a rash vow that cost him dearly?', '["Gideon","Samson","Ibzan","Jephthah"]'::jsonb, 3),
('hs', 'Hannah prayed desperately for a son and God gave her whom?', '["Samuel","Samson","Solomon","Saul"]'::jsonb, 0),
('hs', 'What sacred object did the Philistines capture in battle?', '["The bronze altar","The ark of the covenant","The golden lampstand","The tablets of the law"]'::jsonb, 1),
('hs', 'Which idol kept falling on its face before the captured ark?', '["Baal","Molech","Dagon","Asherah"]'::jsonb, 2),
('hs', 'David secretly cut the corner of Saul''s robe in a cave near where?', '["Ziklag","Adullam","Keilah","En Gedi"]'::jsonb, 3),
('hs', 'Which son of David led a rebellion against him?', '["Absalom","Amnon","Adonijah","Nathan"]'::jsonb, 0),
('hs', 'How was Absalom caught as he fled the battle?', '["His chariot broke","His head caught in a tree","His horse fell","He was surrounded at a river"]'::jsonb, 1),
('hs', 'Nathan confronted David''s sin with a parable about what?', '["A lost coin","A broken wall","A poor man''s ewe lamb","Two brothers"]'::jsonb, 2),
('hs', 'Who was Bathsheba''s first husband, whom David had killed?', '["Joab","Abner","Ahithophel","Uriah the Hittite"]'::jsonb, 3),
('hs', 'Where did God appear to Solomon in a dream, offering him anything?', '["Gibeon","Jerusalem","Hebron","Shiloh"]'::jsonb, 0),
('hs', 'Elisha purified the bad water of which city with a bowl of salt?', '["Samaria","Jericho","Bethel","Dothan"]'::jsonb, 1),
('hs', 'Which king of Judah was healed and given fifteen more years of life?', '["Josiah","Uzziah","Hezekiah","Jehoshaphat"]'::jsonb, 2),
('hs', 'The Assyrians conquered which kingdom in 722 BC?', '["Judah","Moab","Aram","The northern kingdom of Israel"]'::jsonb, 3),
('hs', 'Which Babylonian king destroyed Jerusalem and its temple?', '["Nebuchadnezzar","Belshazzar","Darius","Sennacherib"]'::jsonb, 0),
('hs', 'Who led the rebuilding of Jerusalem''s walls in just 52 days?', '["Ezra","Nehemiah","Zerubbabel","Haggai"]'::jsonb, 1),
('hs', 'Which priest and scribe taught the returned exiles the Law?', '["Nehemiah","Zechariah","Ezra","Malachi"]'::jsonb, 2),
('hs', 'Cyrus, who let the exiles return home, ruled which empire?', '["Babylon","Assyria","Greece","Persia"]'::jsonb, 3);

-- Psalms, Proverbs & wisdom (15)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('hs', 'Proverbs says the fear of the LORD is the beginning of what?', '["Knowledge","Peace","Strength","Riches"]'::jsonb, 0),
('hs', 'Psalm 119, the longest chapter in the Bible, is almost entirely about what?', '["Creation","God''s word","The temple","King David''s battles"]'::jsonb, 1),
('hs', 'Which psalm opens with "My God, my God, why have you forsaken me?"', '["Psalm 51","Psalm 90","Psalm 22","Psalm 121"]'::jsonb, 2),
('hs', 'After losing everything, Job refused to do what?', '["Speak to his friends","Leave his house","Pray","Curse God"]'::jsonb, 3),
('hs', 'How many friends first came to sit with Job in his suffering?', '["Three","Two","Four","Seven"]'::jsonb, 0),
('hs', 'Ecclesiastes 3 says there is a time and season for what?', '["Only joy","Every activity under heaven","The righteous alone","Kings and princes"]'::jsonb, 1),
('hs', 'Who is credited with writing most of the book of Proverbs?', '["David","Hezekiah","Solomon","Agur"]'::jsonb, 2),
('hs', '"Trust in the LORD with all your heart" comes from which book?', '["Psalms","Job","Ecclesiastes","Proverbs"]'::jsonb, 3),
('hs', 'Proverbs 31 famously describes what?', '["A noble wife","A wise king","A faithful son","A good judge"]'::jsonb, 0),
('hs', 'Which Old Testament book is a poetic celebration of love?', '["Lamentations","Song of Solomon","Ruth","Esther"]'::jsonb, 1),
('hs', 'What is the shortest psalm?', '["Psalm 1","Psalm 150","Psalm 117","Psalm 23"]'::jsonb, 2),
('hs', 'What is the longest chapter in the Bible?', '["Psalm 78","Isaiah 53","Psalm 22","Psalm 119"]'::jsonb, 3),
('hs', '"Be still, and know that I am God" is found in which book?', '["Psalms","Isaiah","Job","1 Kings"]'::jsonb, 0),
('hs', 'Which psalm is David''s prayer of repentance after his sin with Bathsheba?', '["Psalm 23","Psalm 51","Psalm 100","Psalm 2"]'::jsonb, 1),
('hs', 'Ecclesiastes opens by declaring that everything is what?', '["Beautiful","Eternal","Meaningless","Ordered"]'::jsonb, 2);

-- Major prophets (15)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('hs', 'Which prophet saw the Lord on a throne, high and lifted up, with seraphim?', '["Isaiah","Ezekiel","Daniel","Jeremiah"]'::jsonb, 0),
('hs', 'What touched Isaiah''s lips to cleanse him for his calling?', '["Pure water","A burning coal","A scroll","Anointing oil"]'::jsonb, 1),
('hs', 'Isaiah 53 describes a servant who suffers for whose sins?', '["His own","Israel''s kings only","Ours","The Gentiles only"]'::jsonb, 2),
('hs', 'Which prophet is known as the "weeping prophet"?', '["Ezekiel","Hosea","Amos","Jeremiah"]'::jsonb, 3),
('hs', 'Where was Jeremiah thrown by officials who hated his message?', '["A muddy cistern","A lions'' den","A furnace","A prison island"]'::jsonb, 0),
('hs', 'Which prophet saw a valley of dry bones come to life?', '["Isaiah","Ezekiel","Zechariah","Joel"]'::jsonb, 1),
('hs', 'Ezekiel''s famous opening vision included wheels within what?', '["Fire","Clouds","Wheels","Wings"]'::jsonb, 2),
('hs', 'Which prophet served in the courts of Babylon after being taken as a youth?', '["Ezra","Isaiah","Habakkuk","Daniel"]'::jsonb, 3),
('hs', 'Daniel interpreted Nebuchadnezzar''s dream about a giant what?', '["Statue","Tree","Beast","Mountain"]'::jsonb, 0),
('hs', 'What happened to Nebuchadnezzar when he boasted about his greatness?', '["He went blind","He lived like a wild animal, eating grass","He lost his kingdom to Egypt","He was struck mute"]'::jsonb, 1),
('hs', '"For I know the plans I have for you, declares the LORD" comes from which prophet?', '["Isaiah","Ezekiel","Jeremiah","Daniel"]'::jsonb, 2),
('hs', 'Isaiah prophesied that the virgin''s son would be given what name?', '["Wonderful","Jesse''s Branch","Prince","Immanuel"]'::jsonb, 3),
('hs', 'The book of Lamentations mourns the destruction of which city?', '["Jerusalem","Samaria","Nineveh","Babylon"]'::jsonb, 0),
('hs', 'God made Ezekiel a "watchman" — his job was to do what?', '["Guard the temple gates","Warn the people","Count the exiles","Watch the stars"]'::jsonb, 1),
('hs', 'Daniel told Belshazzar the writing on the wall meant his kingdom would be what?', '["Blessed","Enlarged","Given to the Medes and Persians","Spared for his father''s sake"]'::jsonb, 2);

-- Minor prophets (15)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('hs', 'Hosea''s painful marriage was a living picture of what?', '["God''s love for unfaithful Israel","The coming exile","The law''s demands","The temple''s fall"]'::jsonb, 0),
('hs', 'Which prophet described a devastating plague of locusts?', '["Amos","Joel","Nahum","Haggai"]'::jsonb, 1),
('hs', '"Let justice roll on like a river" was the cry of which prophet?', '["Hosea","Obadiah","Amos","Zephaniah"]'::jsonb, 2),
('hs', 'What was Amos''s job before God called him to prophesy?', '["Priest","Scribe","Soldier","Shepherd"]'::jsonb, 3),
('hs', 'The single-chapter book of Obadiah pronounces judgment on which nation?', '["Edom","Moab","Ammon","Philistia"]'::jsonb, 0),
('hs', 'Jonah warned Nineveh it would be overthrown in how many days?', '["Three","Forty","Seven","Seventy"]'::jsonb, 1),
('hs', 'Which prophet foretold that Israel''s ruler would come from Bethlehem?', '["Zechariah","Hosea","Micah","Joel"]'::jsonb, 2),
('hs', 'Nahum prophesied the fall of which cruel city?', '["Babylon","Tyre","Damascus","Nineveh"]'::jsonb, 3),
('hs', 'Habakkuk declared, "The righteous shall live by" what?', '["Faith","The law","Hope","Wisdom"]'::jsonb, 0),
('hs', 'Haggai urged the returned exiles to finish rebuilding what?', '["The city walls","The temple","Their houses","The palace"]'::jsonb, 1),
('hs', 'Zechariah foresaw a humble king coming to Zion riding on what?', '["A war horse","A chariot","A donkey","A cloud"]'::jsonb, 2),
('hs', 'Malachi, the last Old Testament book, rebuked the people for robbing God in what?', '["Sacrifices","Sabbaths","Vows","Tithes and offerings"]'::jsonb, 3),
('hs', 'Micah 6:8 says the LORD requires us to act justly, love mercy, and walk how?', '["Humbly with your God","Boldly before kings","Carefully among nations","Quickly toward Zion"]'::jsonb, 0),
('hs', 'Zephaniah''s central theme is the coming day of the what?', '["Harvest","LORD","Kingdom","Covenant"]'::jsonb, 1),
('hs', 'Which prophet is the final book of the Old Testament?', '["Zechariah","Haggai","Malachi","Zephaniah"]'::jsonb, 2);

-- Gospels deeper (30)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('hs', 'Which Gospel opens with "In the beginning was the Word"?', '["John","Matthew","Mark","Luke"]'::jsonb, 0),
('hs', 'Which Gospel writer was a physician?', '["Matthew","Luke","Mark","John"]'::jsonb, 1),
('hs', 'Which is the shortest of the four Gospels?', '["Luke","John","Mark","Matthew"]'::jsonb, 2),
('hs', 'The visit of the Magi is recorded in which Gospel?', '["Mark","Luke","John","Matthew"]'::jsonb, 3),
('hs', 'What kind of tree did Zacchaeus climb to see Jesus?', '["A sycamore-fig tree","An olive tree","A cedar","A palm"]'::jsonb, 0),
('hs', 'When did Nicodemus first come to talk with Jesus?', '["At the temple feast","At night","After the resurrection","On the Sabbath"]'::jsonb, 1),
('hs', 'Jesus told Nicodemus that to see God''s kingdom a person must be what?', '["Baptized in the Jordan","A child of Abraham","Born again","Perfect in the law"]'::jsonb, 2),
('hs', 'Where did Jesus meet the Samaritan woman?', '["At the city gate","In a synagogue","At the market","At Jacob''s well"]'::jsonb, 3),
('hs', 'How many husbands did Jesus say the Samaritan woman had had?', '["Five","Two","Three","Seven"]'::jsonb, 0),
('hs', 'Who appeared talking with Jesus at the Transfiguration?', '["Abraham and David","Moses and Elijah","Enoch and Noah","Isaiah and Jeremiah"]'::jsonb, 1),
('hs', 'Which three disciples witnessed the Transfiguration?', '["Peter, Andrew, and Philip","Matthew, Thomas, and James","Peter, James, and John","James, John, and Andrew"]'::jsonb, 2),
('hs', 'Who asked Jesus, "What is truth?"', '["Herod","Caiaphas","Annas","Pilate"]'::jsonb, 3),
('hs', 'Which prisoner did the crowd choose to release instead of Jesus?', '["Barabbas","Malchus","Silas","Demas"]'::jsonb, 0),
('hs', 'Who was forced to carry Jesus'' cross?', '["Joseph of Arimathea","Simon of Cyrene","Nicodemus","John Mark"]'::jsonb, 1),
('hs', 'What did the sign above Jesus on the cross say he was?', '["A blasphemer","A prophet","King of the Jews","Son of Joseph"]'::jsonb, 2),
('hs', 'How long did darkness cover the land while Jesus hung on the cross?', '["One hour","Six hours","The whole day","Three hours"]'::jsonb, 3),
('hs', 'What tore from top to bottom when Jesus died?', '["The temple curtain","The high priest''s robe","The city gate","The scroll of the law"]'::jsonb, 0),
('hs', 'Who buried Jesus in his own new tomb?', '["Nicodemus","Joseph of Arimathea","Simon Peter","Lazarus"]'::jsonb, 1),
('hs', 'The risen Jesus walked unrecognized with two disciples on the road to where?', '["Bethany","Jericho","Emmaus","Galilee"]'::jsonb, 2),
('hs', 'How many days after the resurrection did Jesus ascend to heaven?', '["Three","Seven","Ten","Forty"]'::jsonb, 3),
('hs', 'After the resurrection, how many times did Jesus ask Peter, "Do you love me?"', '["Three","One","Two","Seven"]'::jsonb, 0),
('hs', 'What did John the Baptist eat in the wilderness?', '["Bread and fish","Locusts and wild honey","Figs and olives","Manna"]'::jsonb, 1),
('hs', 'John the Baptist was beheaded at the request of whose daughter?', '["Pilate''s wife''s","The high priest''s","Herodias''s","Caesar''s"]'::jsonb, 2),
('hs', 'How many days was Jesus tempted in the wilderness?', '["Seven","Twelve","Thirty","Forty"]'::jsonb, 3),
('hs', 'How did Jesus answer each of Satan''s temptations?', '["By quoting Scripture","With a miracle","With silence","By calling angels"]'::jsonb, 0),
('hs', 'Jesus said, "I am the way, the truth, and the..."', '["door","life","light","vine"]'::jsonb, 1),
('hs', 'Complete the "I am" statement: "I am the bread of..."', '["heaven","the covenant","life","angels"]'::jsonb, 2),
('hs', 'Jesus said, "I am the vine; you are the..."', '["fruit","gardeners","roots","branches"]'::jsonb, 3),
('hs', 'The good shepherd lays down his life for the what?', '["Sheep","Kingdom","Truth","Lost"]'::jsonb, 0),
('hs', 'Which disciple brought Jesus the boy with five loaves and two fish?', '["Philip","Andrew","Peter","Thomas"]'::jsonb, 1);

-- Acts & the early church (15)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('hs', 'Who wrote the book of Acts?', '["Paul","Peter","Luke","John Mark"]'::jsonb, 2),
('hs', 'Who was chosen to replace Judas among the twelve apostles?', '["Barnabas","Stephen","Silas","Matthias"]'::jsonb, 3),
('hs', 'What appeared over the believers'' heads at Pentecost?', '["Tongues of fire","Doves","Crowns of light","Golden clouds"]'::jsonb, 0),
('hs', 'About how many people believed after Peter''s sermon at Pentecost?', '["120","3,000","500","12,000"]'::jsonb, 1),
('hs', 'Ananias and Sapphira died after doing what?', '["Stealing from widows","Denying Jesus publicly","Lying about their offering","Worshiping idols"]'::jsonb, 2),
('hs', 'Cornelius, the first Gentile household Peter visited, was a what?', '["Tax collector","Merchant","Governor","Roman centurion"]'::jsonb, 3),
('hs', 'Peter''s rooftop vision showed a great sheet filled with what?', '["All kinds of animals","Scrolls","Loaves of bread","Fishing nets"]'::jsonb, 0),
('hs', 'Where were believers first called Christians?', '["Jerusalem","Antioch","Rome","Ephesus"]'::jsonb, 1),
('hs', 'Who traveled with Paul on his first missionary journey?', '["Silas","Timothy","Barnabas","Titus"]'::jsonb, 2),
('hs', 'Who fell from a third-story window while Paul preached late into the night?', '["Tychicus","Trophimus","Aquila","Eutychus"]'::jsonb, 3),
('hs', 'Paul and Silas were imprisoned after being beaten in which city?', '["Philippi","Corinth","Athens","Thessalonica"]'::jsonb, 0),
('hs', 'What happened while Paul and Silas sang hymns in prison at midnight?', '["An angel opened the gate","An earthquake shook the prison open","The guards fell asleep","A crowd freed them"]'::jsonb, 1),
('hs', 'On which island was Paul shipwrecked on his way to Rome?', '["Cyprus","Crete","Malta","Patmos"]'::jsonb, 2),
('hs', 'What bit Paul on Malta without harming him?', '["A scorpion","A wild dog","A spider","A viper"]'::jsonb, 3),
('hs', 'The book of Acts ends with Paul preaching in which city?', '["Rome","Jerusalem","Antioch","Caesarea"]'::jsonb, 0);

-- Paul's letters (30)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('hs', 'How many New Testament letters are traditionally attributed to Paul?', '["7","10","21","13"]'::jsonb, 3),
('hs', '"For all have sinned and fall short of the glory of God" is from which letter?', '["Romans","Galatians","Ephesians","Hebrews"]'::jsonb, 0),
('hs', '"The wages of sin is death, but the gift of God is eternal life" is from which letter?', '["1 Corinthians","Romans","Philippians","1 John"]'::jsonb, 1),
('hs', 'The famous "love chapter" is found where?', '["Romans 8","John 3","1 Corinthians 13","1 John 4"]'::jsonb, 2),
('hs', 'Paul says faith, hope, and love remain — but the greatest of these is what?', '["Faith","Hope","Wisdom","Love"]'::jsonb, 3),
('hs', 'The fruit of the Spirit is listed in which letter?', '["Galatians","Colossians","Titus","James"]'::jsonb, 0),
('hs', 'How many qualities make up the fruit of the Spirit?', '["Seven","Nine","Ten","Twelve"]'::jsonb, 1),
('hs', 'The armor of God is described in which letter?', '["Romans","Philippians","Ephesians","2 Timothy"]'::jsonb, 2),
('hs', 'In the armor of God, what is the sword of the Spirit?', '["Faith","Prayer","Righteousness","The word of God"]'::jsonb, 3),
('hs', '"I can do all things through Christ who strengthens me" is from which letter?', '["Philippians","Colossians","Romans","2 Corinthians"]'::jsonb, 0),
('hs', 'Paul wrote Philippians — a letter overflowing with joy — from where?', '["A ship","Prison","Athens","The desert"]'::jsonb, 1),
('hs', '"Rejoice in the Lord always; again I will say, rejoice" comes from which letter?', '["1 Thessalonians","Galatians","Philippians","Philemon"]'::jsonb, 2),
('hs', 'Colossians declares that Christ is the image of the invisible what?', '["Kingdom","Glory","Church","God"]'::jsonb, 3),
('hs', 'The letters 1 and 2 Timothy were written to a young pastor serving where?', '["Ephesus","Corinth","Philippi","Rome"]'::jsonb, 0),
('hs', 'What was the name of Timothy''s grandmother, known for her sincere faith?', '["Priscilla","Lois","Eunice","Phoebe"]'::jsonb, 1),
('hs', 'Paul left Titus to organize the churches on which island?', '["Cyprus","Malta","Crete","Rhodes"]'::jsonb, 2),
('hs', 'Paul''s letter to Philemon concerns a runaway slave named what?', '["Tychicus","Epaphras","Archippus","Onesimus"]'::jsonb, 3),
('hs', '"Pray without ceasing" appears in which letter?', '["1 Thessalonians","Titus","Romans","Ephesians"]'::jsonb, 0),
('hs', '1 Thessalonians comforts believers with teaching about what future event?', '["Pentecost","The Lord''s return","The temple''s fall","The church''s growth"]'::jsonb, 1),
('hs', 'Which letter says, "If anyone is not willing to work, let him not eat"?', '["1 Corinthians","Philemon","2 Thessalonians","Galatians"]'::jsonb, 2),
('hs', '"For by grace you have been saved through faith" is from which letter?', '["Romans","Colossians","Philippians","Ephesians"]'::jsonb, 3),
('hs', 'Which letter compares the church to a body with many members?', '["1 Corinthians","1 Timothy","Titus","Philemon"]'::jsonb, 0),
('hs', 'Paul describes his "thorn in the flesh" in which letter?', '["Romans","2 Corinthians","Galatians","1 Timothy"]'::jsonb, 1),
('hs', 'God told Paul, "My grace is sufficient for you, for my power is made perfect in..."', '["suffering","prayer","weakness","patience"]'::jsonb, 2),
('hs', 'Which letter confronts teachers who demanded Gentile believers be circumcised?', '["Philippians","Colossians","1 Thessalonians","Galatians"]'::jsonb, 3),
('hs', '"I have fought the good fight, I have finished the race" is from which letter?', '["2 Timothy","1 Timothy","Titus","Philemon"]'::jsonb, 0),
('hs', 'Paul told Timothy that all Scripture is what?', '["Written by prophets","God-breathed","Sealed until the end","For priests to interpret"]'::jsonb, 1),
('hs', 'Romans 8 promises that nothing can separate us from what?', '["The church","Our inheritance","The love of God","The promised land"]'::jsonb, 2),
('hs', 'Romans 12 says to be transformed by the renewing of your what?', '["Heart","Spirit","Strength","Mind"]'::jsonb, 3),
('hs', 'Which letter calls the church to unity with "one Lord, one faith, one baptism"?', '["Ephesians","Romans","1 Corinthians","Colossians"]'::jsonb, 0);

-- General epistles (15)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('hs', 'Hebrews presents Jesus as our great high what?', '["Priest","King","Shepherd","Judge"]'::jsonb, 0),
('hs', 'Hebrews 11 defines faith as assurance of things what?', '["Seen","Hoped for","Written","Promised to Israel"]'::jsonb, 1),
('hs', 'James says that faith without works is what?', '["Weak","Small","Dead","Growing"]'::jsonb, 2),
('hs', 'James compares the tongue to a small rudder that steers a what?', '["Chariot","Kingdom","Plow","Ship"]'::jsonb, 3),
('hs', '"Count it all joy when you meet trials" opens which letter?', '["James","1 Peter","Jude","Hebrews"]'::jsonb, 0),
('hs', 'James says the prayer of what kind of person has great power?', '["A wealthy","A righteous","An elderly","A suffering"]'::jsonb, 1),
('hs', '1 Peter says to cast all your what on God, because he cares for you?', '["Plans","Possessions","Anxiety","Praise"]'::jsonb, 2),
('hs', 'Peter calls believers a chosen people and a royal what?', '["Army","Family","Nation","Priesthood"]'::jsonb, 3),
('hs', '2 Peter says that with the Lord, a day is like how long?', '["A thousand years","A watch in the night","An eternity","A vapor"]'::jsonb, 0),
('hs', 'Which letter declares plainly that "God is love"?', '["James","1 John","2 Peter","Hebrews"]'::jsonb, 1),
('hs', '"If we confess our sins, he is faithful and just to forgive us" is from which letter?', '["Jude","Hebrews","1 John","James"]'::jsonb, 2),
('hs', '2 John and 3 John were addressed to "the elect lady" and to which man?', '["Demetrius","Diotrephes","Timothy","Gaius"]'::jsonb, 3),
('hs', 'The short letter of Jude warns the church against what?', '["False teachers","Roman persecution","Famine","Divisions over food"]'::jsonb, 0),
('hs', 'Hebrews says that without faith it is impossible to do what?', '["Enter the temple","Please God","Understand Scripture","Defeat sin"]'::jsonb, 1),
('hs', 'Hebrews warns against neglecting to do what together?', '["Fast","Sing psalms","Meet together","Read the law"]'::jsonb, 2);

-- Revelation & Bible literacy (25)
insert into public.by_bag_questions (level, q, options, answer_idx) values
('hs', 'Who received the visions recorded in Revelation?', '["John","Peter","Paul","James"]'::jsonb, 0),
('hs', 'On which island was John exiled when he saw the visions?', '["Crete","Patmos","Malta","Cyprus"]'::jsonb, 1),
('hs', 'Revelation opens with letters to how many churches?', '["Three","Twelve","Seven","Ten"]'::jsonb, 2),
('hs', 'Which church did Jesus call "lukewarm — neither hot nor cold"?', '["Ephesus","Smyrna","Sardis","Laodicea"]'::jsonb, 3),
('hs', 'Which church was told, "You have abandoned your first love"?', '["Ephesus","Pergamum","Thyatira","Philadelphia"]'::jsonb, 0),
('hs', 'Jesus says in Revelation, "I am the Alpha and the..."', '["Amen","Omega","Almighty","Ancient"]'::jsonb, 1),
('hs', 'How many horsemen of the apocalypse are there?', '["Seven","Twelve","Four","Three"]'::jsonb, 2),
('hs', 'What holy city does John see descending from heaven?', '["New Bethlehem","Mount Zion","Eden restored","The new Jerusalem"]'::jsonb, 3),
('hs', 'The street of the new Jerusalem is made of what?', '["Pure gold","White marble","Crystal","Sapphire"]'::jsonb, 0),
('hs', 'How many gates does the new Jerusalem have?', '["Seven","Twelve","Four","Twenty-four"]'::jsonb, 1),
('hs', 'Revelation 21 promises God will wipe away every what?', '["Sin","Enemy","Tear","Shadow"]'::jsonb, 2),
('hs', 'The tree of life appears in Genesis and again in which book?', '["Malachi","Jude","Hebrews","Revelation"]'::jsonb, 3),
('hs', 'Jesus says in Revelation 3, "Behold, I stand at the door and..."', '["knock","wait","call","watch"]'::jsonb, 0),
('hs', 'Who is "the Lamb" at the center of Revelation''s worship scenes?', '["Michael","Jesus","John","The church"]'::jsonb, 1),
('hs', 'Armageddon in Revelation is the gathering place for what?', '["A wedding feast","A great harvest","A final battle","A new temple"]'::jsonb, 2),
('hs', 'Near its end, Revelation says the Spirit and the bride both say what?', '["Amen","Holy","Worthy","Come"]'::jsonb, 3),
('hs', 'About how many "silent years" passed between the Old and New Testaments?', '["400","100","70","1,000"]'::jsonb, 0),
('hs', 'The New Testament was originally written mostly in which language?', '["Hebrew","Greek","Latin","Aramaic"]'::jsonb, 1),
('hs', 'The first five books of the Bible are together called what?', '["The Chronicles","The Septuagint","The Pentateuch","The Apocrypha"]'::jsonb, 2),
('hs', 'What is the shortest book in the Old Testament?', '["Haggai","Ruth","Nahum","Obadiah"]'::jsonb, 3),
('hs', 'Which Old Testament book never mentions God by name?', '["Esther","Ruth","Ecclesiastes","Song of Solomon"]'::jsonb, 0),
('hs', 'Which is the longest book of the New Testament?', '["Acts","Luke","Matthew","Romans"]'::jsonb, 1),
('hs', 'Isaiah 40:8 — the grass withers and flowers fade, but what stands forever?', '["The heavens","The mountains","The word of our God","The throne of David"]'::jsonb, 2),
('hs', 'What is the number associated with the beast in Revelation?', '["777","144","1,000","666"]'::jsonb, 3),
('hs', 'The Bible was written over roughly how many years, by many authors?', '["1,500","200","500","3,000"]'::jsonb, 0);
