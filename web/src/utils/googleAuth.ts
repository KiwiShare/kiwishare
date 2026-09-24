import type { UserProfile } from '../api/client';

export async function finishGoogleSignIn(
  idToken: string,
  loginWithGoogle: (idToken: string) => Promise<UserProfile>,
  updateUsername: (username: string) => Promise<UserProfile>,
): Promise<UserProfile> {
  let user = await loginWithGoogle(idToken);
  if (!user.needsUsername && user.username?.trim()) return user;

  while (true) {
    const proposed = window.prompt(
      `Signed in as ${user.email}. Choose a KiwiShare username (3-24 letters, numbers, or underscores):`,
      '',
    );

    if (proposed === null) {
      throw new Error('A username is required to finish Google sign-in.');
    }

    const username = proposed.trim();
    if (!/^[a-zA-Z0-9_]{3,24}$/.test(username)) {
      window.alert(
        'Username must be 3-24 characters using only letters, numbers, or underscores.',
      );
      continue;
    }

    user = await updateUsername(username);
    return user;
  }
}
