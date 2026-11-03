# QuoteDay Privacy Policy

*This is a translation of the Korean original. If the two differ, the Korean version prevails.*

**Effective: November 3, 2026**

## In short

QuoteDay has **no accounts of its own and no developer server.**
It does not send your name, email, or phone number to the developer.
Your schedule, notes, and entries stay **on this device**; only hearts and challenge rankings go through Apple's iCloud.
AI chat runs **on your device**, so your questions never leave it.
There are no ads, no tracking, and no analytics tools.

---

## 1. What stays on your device

The items below **never leave your device.** They disappear when you delete the app.

| What | Where |
|---|---|
| Schedule (title, time, memo, repeat) | On-device database |
| Quote notes | On-device database |
| Challenge records (best score, games played) | On-device settings storage |
| App settings (reminder time, appearance, language, preferred categories) | On-device settings storage |
| Nickname | On-device settings storage |
| If you sign in with Apple: the user identifier, name, and email Apple provides | On-device settings storage |
| Quote explanations written by AI | On-device file |
| Downloaded AI model files (optional) | On-device storage |
| Quote cards you create | The Photos app, only if you tap Save |

These values live in a storage space shared by the app and its widget (App Group) so that the
Home Screen widget can show the same content. They still do not leave your device.

If you choose **Sign in with Apple**, the user identifier Apple gives the app, and (once, the first
time) your name and email, are stored on this device only. There is no developer server, so
nothing is sent anywhere. You can also use the app without signing in.

**Exporting is the exception, and it is your choice.** If you export your entries as a file in
Settings, or share a quote card or monthly review as an image, that file goes to **the place you
choose** (the Files app, Mail, another app). You decide where it goes, and the developer cannot see
it. The app never exports anything on its own.

## 2. What goes through Apple iCloud

**Hearts** and **challenge rankings** are features many people see together, so they use Apple's
CloudKit public database. This is all that is stored there.

- **Hearts** — which quotes you hearted, and the total heart count for each quote
- **Challenge rankings** — this season's total score and the number of players in each score range

An **anonymous user identifier** that Apple generates separately for each app is attached. It keeps
the same person from counting a heart on the same quote twice, and lets you see your own hearts on
your other devices. This identifier **does not tell anyone who you are**, and the developer cannot
see your iCloud account or email.

**What other people cannot see:** your name, nickname, score, or rank. The ranking screen only
tells you "roughly where you stand overall" and shows no one else's information.

This data is stored on Apple's servers; the developer runs no separate server. Apple's handling of
it is governed by the [Apple Privacy Policy](https://www.apple.com/legal/privacy/).

The app works normally even if you are not signed in to iCloud. Hearts then stay on this device only.

## 3. Requests that leave your device

**[ZenQuotes](https://zenquotes.io/)** — fetches the "Quote of the day" once a day (you can turn
this off in Settings). **No user information is sent.** As with any internet connection, the IP
address of the connecting device remains on the other server.

Translating English quotes into Korean is done **on your device** (Apple's Translation framework).
The text does not leave your device for translation.

**AI chat and quote explanations** run **on your device.** You choose between Apple's on-device
model (Foundation Models) and the open-source model Qwen3 (Apache 2.0) running directly on your
device. Either way, **your questions and the answers never leave your device**, and there is no
server, API key, or fee. Conversations are not saved and disappear when you close the window. Only
the quote explanations it creates are saved on the device, so they can be reused when you open the
same quote again.

**[Hugging Face](https://huggingface.co/)** — only when you choose Qwen3 in Settings and **tap
Download yourself**, the open-source model file (about 350 MB or 1.1 GB) is downloaded once. **No
user information is sent**, and, as with any internet connection, the IP address of the connecting
device remains on the other server. After the download, the model answers without an internet
connection.

There are no other outside connections. No ad networks or analytics tools are included. The app
includes open-source libraries that run AI on your device, but they make no connections other than
the model download above.

## 4. Device permissions

All are **optional**. The rest of the app works the same if you do not allow them.

- **Notifications** — to show the quote at the time you set, and reminders at your schedule times.
  Notifications are shown by your device itself and do not go through any server.
- **Calendar** — to show your device's events alongside your quotes, and to add events created in
  the app to your device calendar. The events it reads are not sent anywhere.
- **Add photos** — to save the quote cards you create. **It does not read your existing photos.**

## 5. What we do not do

- We do not use the advertising identifier (IDFA) or request app tracking permission.
- We do not match your data against other companies' data.
- We do not sell any data or use it for advertising.
- We do not send usage records to any analytics service.
- We do not send or store the questions you ask the AI or the answers it gives.

## 6. Children under 14

The app is not designed for any particular age group, and it neither asks for nor collects age.
There is no developer server, so no personally identifiable information is collected by the developer.

## 7. Retention and deletion

- **Things on your device** — they disappear when you delete the app.
- **Apple sign-in information and nickname** — signing out in Settings removes them from your
  device. Your quotes and entries stay.
- **Downloaded AI models** — in Settings you can see each model's size and delete it.
- **Hearts** — tapping a heart again to remove it also deletes it from the server.
- **Challenge scores** — rankings roll over to a new season every three months (January, April,
  July, and October 1), and past seasons are no longer used. There is currently no way to delete
  your score records inside the app. If you want them deleted, please contact us below.

## 8. If this policy changes

We edit this document and change the effective date at the top. For major changes, we tell you
inside the app. Past versions remain in this repository's commit history.

## 9. Contact

- Email: `coronet.sob4n@icloud.com`
- Or GitHub issues: https://github.com/BraveKoon/QuoteDay/issues
