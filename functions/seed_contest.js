/**
 * Seeds (or updates) the ITEE Plant Discovery contest.
 *
 * The whole contest lives in one Firestore document so the event can be edited
 * or ended without an app release. Re-run this after changing the copy below.
 *
 *   cd functions && node seed_contest.js
 *
 * To END the contest after the event:
 *   node seed_contest.js --end
 * which sets active:false. The card and section disappear from every phone
 * within seconds, with no update to install.
 */

const admin = require("firebase-admin");

admin.initializeApp({ projectId: "botanica-008" });
const db = admin.firestore();

const END_ONLY = process.argv.includes("--end");

// Europe/Helsinki is UTC+3 in September, so 09:00 local is 06:00Z.
const STARTS = new Date("2026-09-03T06:00:00Z");
const ENDS = new Date("2026-09-03T18:00:00Z");

const contest = {
  title: "ITEE Plant Discovery",
  subtitle: "Intriguing, Twisted, Epic & Enigmatic Plants",
  intro:
    "Explore the garden — indoors and outdoors — and find plants that give you " +
    "different kinds of vibes. There are no right or wrong answers.",
  steps: [
    "Team up with random people, or play alone.",
    "Choose a plant that matches one or several categories.",
    "Take a photo of the plant.",
    "Use the slider to place the plant between the opposites.",
    "There are no right or wrong answers — trust your first impression!",
    "Follow the leaderboard.",
  ],
  axes: [
    { key: "cute_creepy", left: "Cute", right: "Creepy" },
    { key: "chaotic_symmetrical", left: "Chaotic", right: "Symmetrical" },
    { key: "ordinary_mythical", left: "Ordinary", right: "Mythical" },
    { key: "npc_boss", left: "NPC type", right: "Final boss type" },
    { key: "harmless_threat", left: "Harmless", right: "Galactic Threat" },
  ],
  prizeNote:
    "If you voted for a plant that ends up with the most picks, you may win a special prize.",
  startsAt: admin.firestore.Timestamp.fromDate(STARTS),
  endsAt: admin.firestore.Timestamp.fromDate(ENDS),
  active: true,
};

async function main() {
  const ref = db.doc("config/contest");

  if (END_ONLY) {
    await ref.set({ active: false }, { merge: true });
    console.log("Contest ended (active:false). It is now hidden in the app.");
    return;
  }

  await ref.set(contest);
  console.log("Seeded config/contest:");
  console.log(`  ${contest.title}`);
  console.log(`  live ${STARTS.toISOString()} -> ${ENDS.toISOString()}`);
  console.log(`  ${contest.axes.length} scales, ${contest.steps.length} steps`);
}

main().then(() => process.exit(0), (e) => {
  console.error(e);
  process.exit(1);
});
