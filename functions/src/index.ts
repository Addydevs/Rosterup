import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

async function getUserTokens(userIds: string[]): Promise<string[]> {
  if (userIds.length === 0) return [];

  const tokens: string[] = [];
  for (const uid of userIds) {
    const snap = await db.collection("users").doc(uid).get();
    if (snap.exists) {
      const data = snap.data() || {};
      const userTokens = (data.fcmTokens as string[]) || [];
      tokens.push(...userTokens);
    }
  }
  return tokens;
}

function toTimestamp(date: Date): admin.firestore.Timestamp {
  return admin.firestore.Timestamp.fromDate(date);
}

exports.onGameCreated = functions.firestore
  .document("games/{gameId}")
  .onCreate(async (snap, context) => {
    const game = snap.data();
    if (!game) return;

    const teamId = game.teamId as string;
    const teamSnap = await db.collection("teams").doc(teamId).get();
    if (!teamSnap.exists) return;

    const team = teamSnap.data() || {};
    const memberIds = (team.memberIds as string[]) || [];
    const tokens = await getUserTokens(memberIds);

    if (tokens.length === 0) return;

    const payload: admin.messaging.MulticastMessage = {
      tokens,
      notification: {
        title: "New game scheduled",
        body: `Your team has a new game.`,
      },
      data: {
        type: "game_created",
        gameId: context.params.gameId,
        teamId,
      },
    };

    await admin.messaging().sendEachForMulticast(payload);
  });

exports.scheduledGameReminders = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async () => {
    const now = new Date();

    // 24-hour reminders: window from now+24h to now+24h+5m
    const dayStart = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const dayEnd = new Date(dayStart.getTime() + 5 * 60 * 1000);

    const daySnapshot = await db
      .collection("games")
      .where("isActive", "==", true)
      .where("dateTime", ">=", toTimestamp(dayStart))
      .where("dateTime", "<", toTimestamp(dayEnd))
      .where("reminder24Sent", "==", false)
      .get()
      .catch(async (e) => {
        console.error("24h reminder query error", e);
        return await db
          .collection("games")
          .where("isActive", "==", true)
          .where("dateTime", ">=", toTimestamp(dayStart))
          .where("dateTime", "<", toTimestamp(dayEnd))
          .get();
      });

    for (const doc of daySnapshot.docs) {
      const game = doc.data();
      const teamSnap = await db.collection("teams").doc(game.teamId).get();
      if (!teamSnap.exists) continue;
      const team = teamSnap.data() || {};
      const memberIds = (team.memberIds as string[]) || [];
      const tokens = await getUserTokens(memberIds);
      if (tokens.length === 0) continue;

      const payload: admin.messaging.MulticastMessage = {
        tokens,
        notification: {
          title: "Game tomorrow",
          body: `You have a game with ${team.name || "your team"} in 24 hours.`,
        },
        data: {
          type: "game_reminder_24h",
          gameId: doc.id,
          teamId: game.teamId as string,
        },
      };

      await admin.messaging().sendEachForMulticast(payload);
      await doc.ref.set({ reminder24Sent: true }, { merge: true });
    }

    // 1-hour reminders: window from now+1h to now+1h+5m
    const hourStart = new Date(now.getTime() + 1 * 60 * 60 * 1000);
    const hourEnd = new Date(hourStart.getTime() + 5 * 60 * 1000);

    const hourSnapshot = await db
      .collection("games")
      .where("isActive", "==", true)
      .where("dateTime", ">=", toTimestamp(hourStart))
      .where("dateTime", "<", toTimestamp(hourEnd))
      .where("reminder1Sent", "==", false)
      .get()
      .catch(async (e) => {
        console.error("1h reminder query error", e);
        return await db
          .collection("games")
          .where("isActive", "==", true)
          .where("dateTime", ">=", toTimestamp(hourStart))
          .where("dateTime", "<", toTimestamp(hourEnd))
          .get();
      });

    for (const doc of hourSnapshot.docs) {
      const game = doc.data();
      const teamSnap = await db.collection("teams").doc(game.teamId).get();
      if (!teamSnap.exists) continue;
      const team = teamSnap.data() || {};
      const memberIds = (team.memberIds as string[]) || [];
      const tokens = await getUserTokens(memberIds);
      if (tokens.length === 0) continue;

      const payload: admin.messaging.MulticastMessage = {
        tokens,
        notification: {
          title: "Game soon",
          body: `Your game with ${team.name || "your team"} starts in 1 hour.`,
        },
        data: {
          type: "game_reminder_1h",
          gameId: doc.id,
          teamId: game.teamId as string,
        },
      };

      await admin.messaging().sendEachForMulticast(payload);
      await doc.ref.set({ reminder1Sent: true }, { merge: true });
    }

    return;
  });

exports.onGameConfirmationChanged = functions.firestore
  .document("games/{gameId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};

    const beforeConf = before.confirmations || {};
    const afterConf = after.confirmations || {};

    if (JSON.stringify(beforeConf) === JSON.stringify(afterConf)) {
      return;
    }

    const teamId = after.teamId as string;
    const teamSnap = await db.collection("teams").doc(teamId).get();
    if (!teamSnap.exists) return;

    const team = teamSnap.data() || {};
    const adminId = team.adminId as string;
    const tokens = await getUserTokens([adminId]);
    if (tokens.length === 0) return;

    const payload: admin.messaging.MulticastMessage = {
      tokens,
      notification: {
        title: "Game attendance updated",
        body: `Someone changed their status for an upcoming game.`,
      },
      data: {
        type: "confirmation_changed",
        gameId: context.params.gameId,
        teamId,
      },
    };

    await admin.messaging().sendEachForMulticast(payload);
  });

exports.onTeamChatMessage = functions.firestore
  .document("teams/{teamId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const message = snap.data();
    if (!message) return;

    const teamId = context.params.teamId as string;
    const teamSnap = await db.collection("teams").doc(teamId).get();
    if (!teamSnap.exists) return;

    const team = teamSnap.data() || {};
    const memberIds = (team.memberIds as string[]) || [];
    const tokens = await getUserTokens(memberIds);
    if (tokens.length === 0) return;

    const payload: admin.messaging.MulticastMessage = {
      tokens,
      notification: {
        title: `New message in ${team.name || "team chat"}`,
        body: message.text as string,
      },
      data: {
        type: "chat_message",
        teamId,
      },
    };

    await admin.messaging().sendEachForMulticast(payload);
  });
