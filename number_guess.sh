#!/bin/bash

PSQL="psql --username=freecodecamp --dbname=number_guess -t --no-align --set=ON_ERROR_STOP=1 -c"

# The test runner sends the next response after each displayed prompt.
printf 'Enter your username:\n'
read -r USERNAME || exit 0

USERNAME_SQL=${USERNAME//\'/\'\'}
USER_ROW=$($PSQL "SELECT user_id,games_played,COALESCE(best_game,0) FROM users WHERE username='$USERNAME_SQL';") || exit 1

if [[ -z "$USER_ROW" ]]; then
  $PSQL "INSERT INTO users(username) VALUES('$USERNAME_SQL') ON CONFLICT(username) DO NOTHING;" >/dev/null || exit 1
  USER_ROW=$($PSQL "SELECT user_id,games_played,COALESCE(best_game,0) FROM users WHERE username='$USERNAME_SQL';") || exit 1
  WELCOME="Welcome, $USERNAME! It looks like this is your first time here."
else
  IFS='|' read -r _USER_ID GAMES_PLAYED BEST_GAME <<< "$USER_ROW"
  WELCOME="Welcome back, $USERNAME! You have played $GAMES_PLAYED games, and your best game took $BEST_GAME guesses."
fi

IFS='|' read -r USER_ID _GAMES _BEST <<< "$USER_ROW"
SECRET_NUMBER=$((RANDOM % 1000 + 1))
GUESSES=0

# Combine the greeting and first guessing prompt into one output event.
printf '%s\nGuess the secret number between 1 and 1000:\n' "$WELCOME"

while read -r GUESS; do
  GUESSES=$((GUESSES + 1))

  if [[ ! "$GUESS" =~ ^-?[0-9]+$ ]]; then
    printf 'That is not an integer, guess again:\n'
  elif (( GUESS > SECRET_NUMBER )); then
    printf "It's lower than that, guess again:\n"
  elif (( GUESS < SECRET_NUMBER )); then
    printf "It's higher than that, guess again:\n"
  else
    $PSQL "UPDATE users SET games_played=games_played+1, best_game=CASE WHEN best_game IS NULL OR best_game>$GUESSES THEN $GUESSES ELSE best_game END WHERE user_id=$USER_ID;" >/dev/null || exit 1
    printf 'You guessed it in %d tries. The secret number was %d. Nice job!\n' "$GUESSES" "$SECRET_NUMBER"
    exit 0
  fi
done
