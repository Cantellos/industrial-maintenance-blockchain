#!/bin/bash

# ============================================
# SEND EMAIL ALERT
# ============================================

TO_EMAIL="andrea.cantelli@edu.unife.it"
SUBJECT="$1"
MESSAGE="$2"

# Invio email (usa mail se disponibile, altrimenti mailx)
if command -v mail &> /dev/null; then
    echo "$MESSAGE" | mail -s "$SUBJECT" "$TO_EMAIL"
elif command -v mailx &> /dev/null; then
    echo "$MESSAGE" | mailx -s "$SUBJECT" "$TO_EMAIL"
else
    echo "ERRORE: mail/mailx non installato"
    exit 1
fi