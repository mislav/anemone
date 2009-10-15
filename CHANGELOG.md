# Changes since v0.2.0

## External:

* Added ":redirect_limit" option (default 5);
* Ensure that hyperlinks that can't be followed are skipped. Examples:
  - #fragment
  - mailto:mislav@example.com
  - javascript:void()
  - ftp://user:password@example.com/
  - tel:1-408-555-5555

* Old "anemone\_count", "anemone\_pagedepth" cli scripts now available
  through the new `anemone` command;
* No more global `Anemone.options`; parameters hash is unique per crawl.
  This enables running multiple crawls with different parameters;
* Added ":traverse_up => false" option to restrict only to given paths;
* Skip URLs ending in file extensions like ".pdf", ".jpg", etc.;
* Added ":allowed\_urls" and ":skip\_urls" options for specifying
  URL string or regexp patterns to follow or block, respectively.

## Internal:

* crawl options are not an OpenStruct anymore, but a Hash
* added `Page#fetch(url)` as a shortcut for `Page.fetch(url, page)`
* Page body and links are lazily parsed
* added `Page#discard_document!` to delete page body
* introduce `URI::Generic#path_with_query`
* refactored `Anemone::HTTP`
