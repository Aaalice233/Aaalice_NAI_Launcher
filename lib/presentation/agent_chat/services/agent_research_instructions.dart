/// Product research workflows stay outside the Pi runtime and reuse its tools.
String buildAgentResearchInstructions({required bool webAccessEnabled}) => [
  'Character identity and appearance research:',
  '- When a user asks whether you know a named character, asks for that '
      'character\'s tags, or wants to draw them, proactively research before '
      'answering with identity, canonical tags, or appearance. Memory is a '
      'search hypothesis, not evidence. Do not ask the user to direct each '
      'research step. A knowledge question alone does not authorize editing '
      'prompts or generating an image.',
  if (webAccessEnabled)
    '- First use web_search for the character name plus franchise/aliases '
        'to verify identity and discover the English or romanized Danbooru '
        'tag. Read relevant pages with web_read when snippets are insufficient. '
        'A translated name is not automatically a canonical tag.'
  else
    '- Web access is disabled: say that web verification is unavailable. '
        'Continue with the available catalog and gallery evidence; do not '
        'pretend to have searched online or silently enable web access.',
  '- Next call search_tags with mode=search on the candidate English tag '
      'and inspect canonical tag, aliases, category and franchise qualifier. '
      'Chinese translation lookup can help discover candidates, but an absent '
      'optional dictionary is not proof that the character does not exist. '
      'An empty catalog result is also not proof: newer characters may be '
      'missing. Keep unverified spellings explicitly uncertain.',
  '- Then use browse_online_gallery with the verified character tag and '
      'an appropriate tag-search source (Danbooru by default). Inspect several '
      'matching works and get_online_gallery_detail when necessary to obtain '
      'their full tags. Separate stable identity features (hair, eyes, '
      'distinctive accessories) from outfits/forms/versions, pose, background, '
      'other characters and artist/style tags. Do not copy all tags from one '
      'image or treat co-occurrence frequency as canon. Respect user content '
      'filters and do not broaden ratings to get more results.',
  '- Summarize the confirmed identity, canonical English tag, stable feature '
      'tags and version-specific traits with source links. Distinguish '
      'observations from inference, conflicting sources and missing evidence. '
      'Use inspect_images only when visual verification is needed; display '
      'images only when the user asks to see them. Reuse already verified '
      'evidence in this conversation unless the identity/version changes.',
  '- If research leaves multiple plausible characters or meaningful visual '
      'directions, use ask_user_question to resolve the choice. Never invent '
      'three fake alternatives to fill the form; options must be feasible '
      'directions supported by the request or evidence. Recommend exactly one '
      'and explain the tradeoffs. Questions clarify preferences, not tool '
      'permissions. Do not ask for facts you can retrieve yourself.',
].join('\n');
