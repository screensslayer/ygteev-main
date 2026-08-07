// glowlands/data/john-book.js
// Town Book data — The Gospel of John at Meadow Town (Phase 1 slice: chapters 1-3).
//
// Design authority: docs/glowlands-design.md Ch. 3.10 (Town Books), Ch. 2.2 (lie
// taxonomy / type chart), Ch. 5.7 (Lightfound fanfare), Ch. 7 (Meadow Town),
// Ch. 17 (gateway-slice scope).
//
// Pure data module. ES exports only — no three.js, no side effects, no DOM.
//
// SCRIPTURE RULE (LOCKED — Ch. 3.10): this file contains ZERO verse text.
// Sections carry ESV *references only*. All displayed verse text is fetched at
// RUNTIME via ctx.fetchPassage(reference) -> Promise<{reference, translation,
// text} | {error}>, which calls the deployed get-bible-passage edge function
// (ESV; returns 503 {error:"translation_unavailable"} until the ESV key is
// configured). Every reader/challenge UI must degrade gracefully to
// reference + retelling when the fetch fails. Retellings and questions below
// are ORIGINAL prose, faithful to the chapter, quoting nothing.
//
// SECTION CHECKS (Ch. 3.10): every section ends with exactly ONE check —
// either a comprehension `question` (4 choices, warm retry) or, for authored
// memory-verse sections, a `memoryVerse` challenge that REPLACES the question
// ("occasional sections end instead with a memory-verse challenge"). Exactly
// one of `question` / `memoryVerse` is non-null per section. Density here is
// one per chapter — denser than the spec's "one per 2-3 chapters" default,
// which the spec marks tunable; the gateway slice leans dense so the combat
// slice has three serum families to play with.
//
// Memory verses: reference only. The memory-verse challenge fetches the ESV
// text at runtime and builds its blanks by tokenizing the fetched text —
// nothing here to tokenize on purpose. Passing the challenge mints the verse
// as a Truth Serum in the mapped family (Ch. 2.2 type chart; ids must match
// LIE_FAMILIES / TYPE_CHART in ./combat-data.js).
//
// AUDIO: the app's existing narration pipeline (supabase/functions/
// generate-verse-audio) stores one MP3 per verse in the public `verse-audio`
// bucket at {bibleId}/{voiceId}/{BOOK}/{chapter}/{verse}.mp3. The Book of John
// is fully recorded; URLs verified live against prod on 2026-08-04 (HTTP 200,
// audio/mpeg). CAVEAT: those recordings narrate the NLT (the app's daily-plan
// translation), while the Town Book displays ESV — so `audio.translation` is
// 'NLT' and the UI must treat narration as read-aloud audio, never as
// word-for-word highlight text against the ESV. If the Wire phase deems the
// mismatch unacceptable, it should ignore `audio.urls` and ship text-only
// until ESV recordings exist.

export const GLOWLANDS_VERSE_AUDIO = {
  base: 'https://tkesywmshaicjmywbovn.supabase.co/storage/v1/object/public/verse-audio',
  bibleId: 'd6e14a625393b4da-01', // NLT — the recorded-narration catalog's translation
  voiceId: 'NPJ9YKwI4PhhZaBPyKlD', // YGTeeV narrator (same voice as daily plans)
  bookCode: 'JHN',
  translation: 'NLT',
};

export function verseAudioUrl(chapter, verse) {
  const a = GLOWLANDS_VERSE_AUDIO;
  return `${a.base}/${a.bibleId}/${a.voiceId}/${a.bookCode}/${chapter}/${verse}.mp3`;
}

function sectionAudio(chapter, start, end) {
  const urls = [];
  for (let v = start; v <= end; v++) urls.push(verseAudioUrl(chapter, v));
  return { urls, translation: GLOWLANDS_VERSE_AUDIO.translation, perVerse: true };
}

// Lie taxonomy (Ch. 2.2) — one-to-one type chart, mirrored from combat-data.js.
// Each memory verse below is tagged to exactly one lie family; its serum
// counters that family only.
export const LIE_FAMILY_COUNTERS = {
  isolation: 'presence',
  condemnation: 'grace',
  fear: 'courage',
  worthlessness: 'identity',
  despair: 'hope',
  doubt: 'trust',
};

const JOHN_BOOK = {
  meta: {
    bookId: 'john',
    town: 'meadow-town',
    bookTitle: 'The Gospel of John',
    translation: {
      id: 'ESV',
      name: 'English Standard Version',
      note:
        'Text is served at runtime via ctx.fetchPassage / get-bible-passage — ' +
        'never bundled. This module holds references and original prose only.',
    },
    chaptersTotal: 21,
    chaptersIncluded: [1, 2, 3],
    sliceNote:
      'Phase 1 gateway slice ships John 1-3 at the Meadow Town library reading ' +
      'desk (design bible Ch. 17, row 6). Later chapters extend chapters[] ' +
      'without shape changes.',
  },

  chapters: [
    // ------------------------------------------------------------------
    // JOHN 1 — The Light arrives
    // ------------------------------------------------------------------
    {
      chapter: 1,
      title: 'The Light Arrives',
      sections: [
        {
          id: 'john-c1-s1',
          title: 'The Word Comes Close',
          reference: 'John 1:1-18',
          verseRange: [1, 18],
          retelling:
            'John opens his gospel before the first sunrise. Before anything ' +
            'existed, the Word already existed — with God, and himself fully ' +
            'God — and every single thing that has ever been made was made ' +
            'through him. Life itself was in him, and that life shone as ' +
            'light for the human race — light pouring into darkness that the ' +
            'darkness has never managed to put out. God sent a man named John ahead as a ' +
            'witness, so that people would believe; John was never the light ' +
            'himself, only the one pointing at it. Then the true light stepped ' +
            'into the world in person. The world he had made failed to ' +
            'recognize him, and even his own people turned him away. But ' +
            'everyone who welcomed him and trusted his name was adopted ' +
            'into God’s own family as his sons and daughters. Then the Word ' +
            'took on a human body and lived alongside ordinary people, ' +
            'brimming with kindness and unwavering honesty, and those close ' +
            'to him saw his glory.',
          // Memory-verse section (Ch. 3.10): the challenge replaces the
          // comprehension question. ESV text fetched + tokenized at runtime.
          question: null,
          memoryVerse: {
            id: 'john-c1-mv',
            reference: 'John 1:12',
            serum: {
              // Counters Worthlessness lies — becoming a child of God is the
              // identity truth (Ch. 2.2: worthlessness -> identity).
              lieFamily: 'worthlessness',
              counterFamily: 'identity',
            },
            audioUrl: verseAudioUrl(1, 12),
          },
          audio: sectionAudio(1, 1, 18),
        },
        {
          id: 'john-c1-s2',
          title: 'The Witness at the River',
          reference: 'John 1:19-34',
          verseRange: [19, 34],
          retelling:
            'Crowds at the Jordan kept wondering who John the Baptizer really ' +
            'was, so the leaders in Jerusalem sent priests and Levites to ask ' +
            'him directly. Was he the Christ? Elijah come back? The promised ' +
            'prophet? John denied every title. He described himself only as a ' +
            'voice out in the wilderness telling people to straighten the road ' +
            'for the Lord, and he added that someone was already standing ' +
            'among them so much greater that John felt unworthy even to ' +
            'unfasten his sandal. The very next day John saw Jesus walking ' +
            'toward him and announced him to everyone as the Lamb sent from ' +
            'God to carry away the sin of the whole world. Then John told ' +
            'them what he had witnessed: the Spirit drifting down from heaven ' +
            'like a dove and staying on Jesus — the exact sign God had ' +
            'promised. So John testified plainly that this man is the Son of ' +
            'God.',
          question: {
            prompt:
              'When John the Baptizer saw Jesus walking toward him, how did he identify him?',
            choices: [
              'As the prophet Elijah, finally returned',
              'As the Lamb sent from God to carry away the sin of the world',
              'As a new king who would drive out the Romans',
              'As a fellow prophet sent to help him baptize the crowds',
            ],
            correctIndex: 1,
            answerRef: 'John 1:29',
          },
          memoryVerse: null,
          audio: sectionAudio(1, 19, 34),
        },
        {
          id: 'john-c1-s3',
          title: 'The First Followers',
          reference: 'John 1:35-51',
          verseRange: [35, 51],
          retelling:
            'When John pointed out the Lamb of God again the next day, two of ' +
            'his own disciples left him and followed Jesus. Jesus asked what ' +
            'they were seeking, and when they asked where he was staying, he ' +
            'simply invited them along to find out. One of the two, Andrew, ' +
            'immediately hunted down his brother Simon with the news that they ' +
            'had found the Messiah — and Jesus, meeting Simon, gave him a new ' +
            'name meaning rock: Peter. The next day Jesus called Philip to ' +
            'follow him, and Philip ran to tell Nathanael they had found the ' +
            'one Moses and the prophets wrote about — Jesus of Nazareth. ' +
            'Nathanael scoffed that nothing good comes from Nazareth, but ' +
            'Philip did not argue; he just invited him to come meet Jesus ' +
            'himself. When Jesus revealed he had already seen Nathanael under ' +
            'the fig tree, the skeptic confessed him as the Son of God, and ' +
            'Jesus promised he would see far greater things.',
          question: {
            prompt:
              'How did Philip respond when Nathanael doubted that anything good could come from Nazareth?',
            choices: [
              'He argued from the prophets until Nathanael finally gave in',
              'He told Nathanael to wait for a sign from heaven',
              'He simply invited Nathanael to come meet Jesus and see for himself',
              'He gave up and went to find someone less skeptical',
            ],
            correctIndex: 2,
            answerRef: 'John 1:46',
          },
          memoryVerse: null,
          audio: sectionAudio(1, 35, 51),
        },
      ],
    },

    // ------------------------------------------------------------------
    // JOHN 2 — Signs and what they reveal
    // ------------------------------------------------------------------
    {
      chapter: 2,
      title: 'The First Sign',
      sections: [
        {
          id: 'john-c2-s1',
          title: 'The Wedding at Cana',
          reference: 'John 2:1-11',
          verseRange: [1, 11],
          retelling:
            'Jesus, his mother, and his new disciples were guests at a wedding ' +
            'in Cana of Galilee when the celebration hit a crisis: the wine ' +
            'ran out. Jesus’ mother brought the problem straight to him, and ' +
            'though he told her his hour had not yet arrived, she quietly ' +
            'instructed the servants to do whatever he said. Six enormous ' +
            'stone jars stood nearby, the kind used for ceremonial washing. ' +
            'Jesus had the servants fill every jar with water right up to the ' +
            'brim, then draw some out and carry it to the master of the ' +
            'feast. By the time it reached his lips it had become wine — and ' +
            'not just any wine. The master, who had no idea where it came ' +
            'from, marveled that this host had somehow saved the best for ' +
            'last. Only the servants knew the secret. This wedding miracle was ' +
            'the earliest of the signs Jesus performed; through it his glory ' +
            'shone out, and the disciples who saw it put their faith in him.',
          // Memory-verse section (Ch. 3.10): the challenge replaces the
          // comprehension question. ESV text fetched + tokenized at runtime.
          question: null,
          memoryVerse: {
            id: 'john-c2-mv',
            reference: 'John 2:11',
            serum: {
              // Counters Doubt lies — the first sign revealed his glory and
              // his disciples believed (Ch. 2.2: doubt -> trust).
              lieFamily: 'doubt',
              counterFamily: 'trust',
            },
            audioUrl: verseAudioUrl(2, 11),
          },
          audio: sectionAudio(2, 1, 11),
        },
        {
          id: 'john-c2-s2',
          title: 'Cleansing the Temple',
          reference: 'John 2:12-22',
          verseRange: [12, 22],
          retelling:
            'At Passover, Jesus went up to Jerusalem and found the temple ' +
            'courts running like a marketplace — oxen, sheep, and pigeons for ' +
            'sale, money-changers stationed at their tables. He braided ' +
            'himself a whip out of rope and drove the whole operation out, scattering ' +
            'coins across the floor and flipping the tables over, demanding ' +
            'that his Father’s house stop being treated like a bazaar. His ' +
            'disciples remembered a psalm about a passion for God’s house ' +
            'that consumes a person. The leaders demanded a sign to justify ' +
            'his authority, and Jesus gave them a riddle: tear this temple ' +
            'down, and in three days he would raise it up again. They ' +
            'laughed — the building had been under construction for ' +
            'forty-six years. But the temple he meant was his own body. Only ' +
            'after he rose from the dead did his disciples remember this ' +
            'moment and believe both the Scripture and what Jesus had said.',
          question: {
            prompt:
              'When Jesus spoke about a temple being raised in three days, what was he actually talking about?',
            choices: [
              'His own body',
              'Finishing Herod’s construction project faster than planned',
              'Building a brand-new temple in Galilee',
              'The tables and stalls he had just driven out of the courts',
            ],
            correctIndex: 0,
            answerRef: 'John 2:21',
          },
          memoryVerse: null,
          audio: sectionAudio(2, 12, 22),
        },
        {
          id: 'john-c2-s3',
          title: 'He Saw Every Heart',
          reference: 'John 2:23-25',
          verseRange: [23, 25],
          retelling:
            'While Jesus stayed in Jerusalem through the Passover feast, many ' +
            'people watched the signs he was performing and believed in his ' +
            'name. Then John records something surprising: Jesus did not ' +
            'entrust himself to them. Why hold back from his own admirers? ' +
            'Because nobody was a stranger to him. He needed no briefing on ' +
            'human nature, for he could see straight into every heart — and ' +
            'he could tell the difference between excitement stirred up by ' +
            'miracles and the kind of trust that lasts. These three short ' +
            'verses also set the stage for what comes next: out of those very ' +
            'Passover crowds, a respected ruler named Nicodemus will soon ' +
            'slip away to find Jesus at night, carrying honest questions to ' +
            'the one teacher who already sees exactly what is inside him.',
          question: {
            prompt:
              'Why did Jesus hold back from entrusting himself to the crowds who believed after seeing his signs?',
            choices: [
              'The crowds had grown too large for him to teach safely',
              'He was preparing to leave for Galilee that same night',
              'He already knew what was inside every human heart',
              'The religious leaders had warned the crowds to stay away from him',
            ],
            correctIndex: 2,
            answerRef: 'John 2:24-25',
          },
          memoryVerse: null,
          audio: sectionAudio(2, 23, 25),
        },
      ],
    },

    // ------------------------------------------------------------------
    // JOHN 3 — Born anew, loved by God
    // ------------------------------------------------------------------
    {
      chapter: 3,
      title: 'A Second Birth',
      sections: [
        {
          id: 'john-c3-s1',
          title: 'Nicodemus by Night',
          reference: 'John 3:1-15',
          verseRange: [1, 15],
          retelling:
            'Nicodemus — a Pharisee, a ruler of the Jews, a genuine expert — ' +
            'came to Jesus under the cover of night. He opened respectfully, ' +
            'admitting that no one could do such signs unless God were with ' +
            'him. Jesus skipped the pleasantries and went straight to the ' +
            'heart: no one can even see God’s kingdom without being born all ' +
            'over again, born from above. Nicodemus was baffled — how can a ' +
            'grown man be born a second time? Jesus explained that he meant a ' +
            'birth of water and the Spirit: flesh produces flesh, but only ' +
            'the Spirit produces spiritual life. The Spirit works like wind — ' +
            'invisible, yet unmistakably real in its effects. When the great ' +
            'teacher still struggled, Jesus reached back to Moses in the ' +
            'wilderness, where a serpent was lifted on a pole so the dying ' +
            'could look and live. In the same way, the Son of Man would have ' +
            'to be raised high, so that trusting him would mean living ' +
            'forever.',
          question: {
            prompt:
              'What did Jesus tell Nicodemus must happen before anyone can see God’s kingdom?',
            choices: [
              'They must keep the whole law without a single mistake',
              'They must be born again — a new birth from above',
              'They must be born into the right family line',
              'They must study under a great teacher, as Nicodemus had',
            ],
            correctIndex: 1,
            answerRef: 'John 3:3',
          },
          memoryVerse: null,
          audio: sectionAudio(3, 1, 15),
        },
        {
          id: 'john-c3-s2',
          title: 'The Rescue Mission',
          reference: 'John 3:16-21',
          verseRange: [16, 21],
          retelling:
            'Here stands the most famous sentence in the Bible, in its ' +
            'original setting. God’s love for the world ran so deep that he ' +
            'handed over his only Son, and now nobody who trusts him has to ' +
            'perish — endless life is theirs instead. And John immediately heads off a ' +
            'misunderstanding: God did not send his Son on a mission of ' +
            'condemnation. The Son came to rescue the world, not to sentence ' +
            'it, and whoever trusts him faces no condemnation at all. The ' +
            'real dividing line, John explains, is how people respond to ' +
            'light. Light has entered the world, yet some people prefer ' +
            'darkness, because darkness keeps their deeds hidden; they steer ' +
            'clear of the light so nothing gets exposed. But those who live ' +
            'by the truth walk toward the light gladly, happy for it to be ' +
            'seen that everything they do has been done in God. The Son came ' +
            'on a rescue mission, and believing in him is the open door into ' +
            'that light.',
          // Memory-verse section (Ch. 3.10): the challenge replaces the
          // comprehension question. ESV text fetched + tokenized at runtime.
          question: null,
          memoryVerse: {
            id: 'john-c3-mv',
            reference: 'John 3:16',
            serum: {
              // Counters Despair lies — whoever believes will not perish but
              // has eternal life (Ch. 2.2: despair -> hope).
              lieFamily: 'despair',
              counterFamily: 'hope',
            },
            audioUrl: verseAudioUrl(3, 16),
          },
          audio: sectionAudio(3, 16, 21),
        },
        {
          id: 'john-c3-s3',
          title: 'The Friend of the Bridegroom',
          reference: 'John 3:22-36',
          verseRange: [22, 36],
          retelling:
            'Jesus and his disciples moved out into the Judean countryside ' +
            'and began baptizing, while John was still baptizing at Aenon ' +
            'near Salim. Soon John’s disciples came to him rattled: the man ' +
            'he had once vouched for was now drawing everyone away. John’s ' +
            'reply is one of the humblest speeches in Scripture. A person can ' +
            'only receive what heaven chooses to give, he said, and he had ' +
            'told them from the start that he was not the Christ — only the ' +
            'messenger sent ahead. He compared himself to the best man at a ' +
            'wedding, who stands beside the bridegroom and is filled with joy ' +
            'just to hear his voice; that joy was now complete. Jesus must ' +
            'keep growing greater, John said, while he himself grew smaller. ' +
            'The chapter closes with the stakes laid bare: the Father’s love ' +
            'rests on the Son, everything has been placed in his hands, and ' +
            'eternal life belongs to everyone who puts their trust in him.',
          question: {
            prompt:
              'How did John the Baptizer react when told that everyone was flocking to Jesus instead of him?',
            choices: [
              'He sent messengers to call his followers back',
              'He said Jesus must keep growing greater while he himself grew smaller',
              'He moved his baptizing work to the far side of the Jordan',
              'He asked Jesus to wait until his own work was finished',
            ],
            correctIndex: 1,
            answerRef: 'John 3:30',
          },
          memoryVerse: null,
          audio: sectionAudio(3, 22, 36),
        },
      ],
    },
  ],
};

export default JOHN_BOOK;
