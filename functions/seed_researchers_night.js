/**
 * Seeds the Researchers' Night vote — "Secrets of Plants".
 *
 * The University's programme promises this app by name: visitors choose their
 * own route, identify plants along the way, and at the end "cast your vote.
 * Which plant is the strangest, most beautiful, or most astonishing at the
 * Researchers' Night?" The three axes below are exactly those three questions,
 * so what the app asks matches what the programme printed.
 *
 *   cd functions && node seed_researchers_night.js
 *
 * To END it afterwards:
 *   node seed_researchers_night.js --end
 * which sets active:false. The card disappears from every phone within
 * seconds, with no update to install.
 *
 * The whole contest is one Firestore document, so the copy below can be edited
 * and re-run during the evening without an app release.
 */

const admin = require("firebase-admin");

admin.initializeApp({ projectId: "botanica-008" });
const db = admin.firestore();

const END_ONLY = process.argv.includes("--end");

// Friday 25 September 2026, 17:00-21:00 Helsinki. Helsinki is UTC+3 (EEST) in
// September, so 17:00 local is 14:00Z.
//
// The window opens two hours early and closes at midnight on purpose: people
// arrive before the doors officially open and keep voting on the minitrain
// home, and a vote refused by a clock is a worse failure than one cast late.
const STARTS = new Date("2026-09-25T12:00:00Z");
const ENDS = new Date("2026-09-25T21:00:00Z");

const contest = {
  title: "Secrets of Plants",
  subtitle: "Which plant is the strangest, most beautiful, or most astonishing?",
  intro:
    "Welcome to Researchers' Night. Walk the garden — greenhouses and grounds " +
    "— and find the plants that strike you. Pick a route, identify what you " +
    "meet along the way, then cast your vote. There are no right answers: the " +
    "whole point is what YOU noticed.",
  steps: [
    "Pick a trail, or just wander wherever you like.",
    "Found something? Photograph it and add it here.",
    "Place it on the three scales — strange, beautiful, astonishing.",
    "Add as many plants as you like, alone or as a team.",
    "Watch the leaderboard to see what the garden voted for tonight.",
  ],
  // The programme's three questions, each as a scale between opposites. The
  // left-hand label is the ordinary end so the right-hand label — the one the
  // programme actually names — is what a high score means.
  axes: [
    { key: "ordinary_strangest", left: "Ordinary", right: "Strangest" },
    { key: "plain_beautiful", left: "Plain", right: "Most beautiful" },
    { key: "expected_astonishing", left: "As expected", right: "Most astonishing" },
  ],
  prizeNote:
    "The winning plants are announced at the end of the evening in meeting " +
    "room Vanamo. Ask a researcher about any plant you find — that is what " +
    "tonight is for.",
  startsAt: admin.firestore.Timestamp.fromDate(STARTS),
  endsAt: admin.firestore.Timestamp.fromDate(ENDS),
  active: true,
};

async function main() {
  const ref = db.doc("config/contest");

  if (END_ONLY) {
    await ref.set({ active: false }, { merge: true });
    console.log("Researchers' Night vote ENDED (active:false).");
    return;
  }

  await ref.set(contest);
  console.log("Seeded:", contest.title);
  console.log("  opens :", STARTS.toISOString(), "(15:00 Helsinki)");
  console.log("  closes:", ENDS.toISOString(), "(midnight Helsinki)");
  console.log("  axes  :", contest.axes.map((a) => `${a.left} → ${a.right}`).join(" | "));
}

main().then(
  () => process.exit(0),
  (e) => {
    console.error(e);
    process.exit(1);
  },
);
