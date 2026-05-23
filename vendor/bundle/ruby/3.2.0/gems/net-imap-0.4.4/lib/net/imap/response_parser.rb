# frozen_string_literal: true

require_relative "errors"
require_relative "response_parser/parser_utils"

module Net
  class IMAP < Protocol

    # Parses an \IMAP server response.
    class ResponseParser
      include ParserUtils
      extend  ParserUtils::Generator

      # :call-seq: Net::IMAP::ResponseParser.new -> Net::IMAP::ResponseParser
      def initialize
        @str = nil
        @pos = nil
        @lex_state = nil
        @token = nil
      end

      # :call-seq:
      #   parse(str) -> ContinuationRequest
      #   parse(str) -> UntaggedResponse
      #   parse(str) -> TaggedResponse
      #
      # Raises ResponseParseError for unparsable strings.
      def parse(str)
        @str = str
        @pos = 0
        @lex_state = EXPR_BEG
        @token = nil
        return response
      end

      private

      # :stopdoc:

      EXPR_BEG   = :EXPR_BEG     # the default, used in most places
      EXPR_DATA  = :EXPR_DATA    # envelope, body(structure), namespaces

      T_SPACE    = :SPACE        # atom special
      T_ATOM     = :ATOM         # atom (subset of astring chars)
      T_NIL      = :NIL          # subset of atom and label
      T_NUMBER   = :NUMBER       # subset of atom
      T_LBRA     = :LBRA         # subset of atom
      T_PLUS     = :PLUS         # subset of atom; tag special
      T_RBRA     = :RBRA         # atom special; resp_special; valid astring char
      T_QUOTED   = :QUOTED       # starts/end with atom special
      T_BSLASH   = :BSLASH       # atom special; quoted special
      T_LPAR     = :LPAR         # atom special; paren list delimiter
      T_RPAR     = :RPAR         # atom special; paren list delimiter
      T_STAR     = :STAR         # atom special; list wildcard
      T_PERCENT  = :PERCENT      # atom special; list wildcard
      T_LITERAL  = :LITERAL      # starts with atom special
      T_CRLF     = :CRLF         # atom special; text special; quoted special
      T_TEXT     = :TEXT         # any char except CRLF
      T_EOF      = :EOF          # end of response string

      module ResponseConditions
        OK      = "OK"
        NO      = "NO"
        BAD     = "BAD"
        BYE     = "BYE"
        PREAUTH = "PREAUTH"

        RESP_COND_STATES      = [OK, NO, BAD              ].freeze
        RESP_DATA_CONDS       = [OK, NO, BAD, BYE,        ].freeze
        AUTH_CONDS            = [OK,               PREAUTH].freeze
        GREETING_CONDS        = [OK,          BYE, PREAUTH].freeze
        RESP_CONDS            = [OK, NO, BAD, BYE, PREAUTH].freeze
      end
      include ResponseConditions

      module Patterns

        module CharClassSubtraction
          refine Regexp do
            def -(rhs); /[#{source}&&[^#{rhs.source}]]/n.freeze end
          end
        end
        using CharClassSubtraction

        # From RFC5234, "Augmented BNF for Syntax Specifications: ABNF"
        # >>>
        #   ALPHA   =  %x41-5A / %x61-7A   ; A-Z / a-z
        #   CHAR    = %x01-7F
        #   CRLF    =  CR LF
        #                   ; Internet standard newline
        #   CTL     = %x00-1F / %x7F
        #                ; controls
        #   DIGIT   =  %x30-39
        #                   ; 0-9
        #   DQUOTE  =  %x22
        #                   ; " (Double Quote)
        #   HEXDIG  =  DIGIT / "A" / "B" / "C" / "D" / "E" / "F"
        #   OCTET   = %x00-FF
        #   SP      =  %x20
        module RFC5234
          ALPHA     = /[A-Za-z]/n
          CHAR      = /[\x01-\x7f]/n
          CRLF      = /\r\n/n
          CTL       = /[\x00-\x1F\x7F]/n
          DIGIT     = /\d/n
          DQUOTE    = /"/n
          HEXDIG    = /\h/
          OCTET     = /[\x00-\xFF]/n # not using /./m for embedding purposes
          SP        = / /n
        end

        # UTF-8, a transformation format of ISO 10646
        # >>>
        #   UTF8-1      = %x00-7F
        #   UTF8-tail   = %x80-BF
        #   UTF8-2      = %xC2-DF UTF8-tail
        #   UTF8-3      = %xE0 %xA0-BF UTF8-tail / %xE1-EC 2( UTF8-tail ) /
        #                 %xED %x80-9F UTF8-tail / %xEE-EF 2( UTF8-tail )
        #   UTF8-4      = %xF0 %x90-BF 2( UTF8-tail ) / %xF1-F3 3( UTF8-tail ) /
        #                 %xF4 %x80-8F 2( UTF8-tail )
        #   UTF8-char   = UTF8-1 / UTF8-2 / UTF8-3 / UTF8-4
        #   UTF8-octets = *( UTF8-char )
        #
        # n.b. String * Integer is used for repetition, rather than /x{3}/,
        # because ruby 3.2's linear-time cache-based optimization doesn't work
        # with "bounded or fixed times repetition nesting in another repetition
        # (e.g. /(a{2,3})*/). It is an implementation issue entirely, but we
        # believe it is hard to support this case correctly."
        # See https://bugs.ruby-lang.org/issues/19104
        module RFC3629
          UTF8_1      = /[\x00-\x7f]/n # aka ASCII 7bit
          UTF8_TAIL   = /[\x80-\xBF]/n
          UTF8_2      = /[\xC2-\xDF]#{UTF8_TAIL}/n
          UTF8_3      = Regexp.union(/\xE0[\xA0-\xBF]#{UTF8_TAIL}/n,
                                     /\xED[\x80-\x9F]#{UTF8_TAIL}/n,
                                     /[\xE1-\xEC]#{    UTF8_TAIL.source * 2}/n,
                                     /[\xEE-\xEF]#{    UTF8_TAIL.source * 2}/n)
          UTF8_4      = Regexp.union(/[\xF1-\xF3]#{    UTF8_TAIL.source * 3}/n,
                                     /\xF0[\x90-\xBF]#{UTF8_TAIL.source * 2}/n,
                                     /\xF4[\x80-\x8F]#{UTF8_TAIL.source * 2}/n)
          UTF8_CHAR   = Regexp.union(UTF8_1, UTF8_2, UTF8_3, UTF8_4)
          UTF8_OCTETS = /#{UTF8_CHAR}*/n
        end

        include RFC5234
        include RFC3629

        # CHAR8           = %x01-ff
        #                     ; any OCTET except NUL, %x00
        CHAR8             = /[\x01-\xff]/n

        # list-wildcards  = "%" / "*"
        LIST_WILDCARDS    = /[%*]/n
        # quoted-specials = DQUOTE / "\"
        QUOTED_SPECIALS   = /["\\]/n
        # resp-specials   = "]"
        RESP_SPECIALS     = /[\]]/n

        # atomish         = 1*<any ATOM-CHAR except "[">
        #                 ; We use "atomish" for msg-att and section, in order
        #                 ; to simplify "BODY[HEADER.FIELDS (foo bar)]".
        #
        # atom-specials   = "(" / ")" / "{" / SP / CTL / list-wildcards /
        #                   quoted-specials / resp-specials
        # ATOM-CHAR       = <any CHAR except atom-specials>
        # atom            = 1*ATOM-CHAR
        # ASTRING-CHAR    = ATOM-CHAR / resp-specials
        # tag             = 1*<any ASTRING-CHAR except "+">

        ATOM_SPECIALS     = /[(){ \x00-\x1f\x7f%*"\\\]]/n
        ASTRING_SPECIALS  = /[(){ \x00-\x1f\x7f%*"\\]/n

        ASTRING_CHAR      = CHAR - ASTRING_SPECIALS
        ATOM_CHAR         = CHAR - ATOM_SPECIALS

        ATOM              = /#{ATOM_CHAR}+/n
        ASTRING_CHARS     = /#{ASTRING_CHAR}+/n
        ATOMISH           = /#{ATOM_CHAR    - /[\[]/ }+/
        TAG               = /#{ASTRING_CHAR - /[+]/  }+/

        # TEXT-CHAR       = <any CHAR except CR and LF>
        TEXT_CHAR         = CHAR - /[\r\n]/

        # resp-text-code  = ... / atom [SP 1*<any TEXT-CHAR except "]">]
        CODE_TEXT_CHAR    = TEXT_CHAR - RESP_SPECIALS
        CODE_TEXT         = /#{CODE_TEXT_CHAR}+/n

        # flag            = "\Answered" / "\Flagged" / "\Deleted" /
        #                   "\Seen" / "\Draft" / flag-keyword / flag-extension
        #                     ; Does not include "\Recent"
        # flag-extension  = "\" atom
        #                     ; Future expansion.  Client implementations
        #                     ; MUST accept flag-extension flags.  Server
        #                     ; implementations MUST NOT generate
        #                     ; flag-extension flags except as defined by
        #                     ; a future Standard or Standards Track
        #                     ; revisions of this specification.
        # flag-keyword    = "$MDNSent" / "$Forwarded" / "$Junk" /
        #                   "$NotJunk" / "$Phishing" / atom
        # flag-perm       = flag / "\*"
        #
        # Not checking for max one mbx-list-sflag in the parser.
        # >>>
        # mbx-list-oflag  = "\Noinferiors" / child-mbox-flag /
        #                   "\Subscribed" / "\Remote" / flag-extension
        #                    ; Other flags; multiple from this list are
        #                    ; possible per LIST response, but each flag
        #                    ; can only appear once per LIST response
        # mbx-list-sflag  = "\NonExistent" / "\Noselect" / "\Marked" /
        #                   "\Unmarked"
        #                    ; Selectability flags; only one per LIST response
        # child-mbox-flag =  "\HasChildren" / "\HasNoChildren"
        #                    ; attributes for the CHILDREN return option, at most
        #                    ; one possible per LIST response
        FLAG              = /\\?#{ATOM}/n
        FLAG_EXTENSION    = /\\#{ATOM}/n
        FLAG_KEYWORD      = ATOM
        FLAG_PERM         = Regexp.union(FLAG, "\\*")
        MBX_FLAG          = FLAG_EXTENSION

        # flag-list       = "(" [flag *(SP flag)] ")"
        #
        # part of resp-text-code:
        # >>>
        #   "PERMANENTFLAGS" SP "(" [flag-perm *(SP flag-perm)] ")"
        #
        # parens from mailbox-list are included in the regexp:
        # >>>
        #   mbx-list-flags  = *(mbx-list-oflag SP) mbx-list-sflag
        #                     *(SP mbx-list-oflag) /
        #                     mbx-list-oflag *(SP mbx-list-oflag)
        FLAG_LIST      = /\G\((#{FLAG     }(?:#{SP}#{FLAG     })*|)\)/ni
        FLAG_PERM_LIST = /\G\((#{FLAG_PERM}(?:#{SP}#{FLAG_PERM})*|)\)/ni
        MBX_LIST_FLAGS = /\G\((#{MBX_FLAG }(?:#{SP}#{MBX_FLAG })*|)\)/ni

        # RFC3501:
        #   QUOTED-CHAR   = <any TEXT-CHAR except quoted-specials> /
        #                   "\" quoted-specials
        # RFC9051:
        #   QUOTED-CHAR   = <any TEXT-CHAR except quoted-specials> /
        #                   "\" quoted-specials / UTF8-2 / UTF8-3 / UTF8-4
        # RFC3501 & RFC9051:
        #   quoted          = DQUOTE *QUOTED-CHAR DQUOTE
        QUOTED_CHAR_safe  = TEXT_CHAR - QUOTED_SPECIALS
        QUOTED_CHAR_esc   = /\\#{QUOTED_SPECIALS}/n
        QUOTED_CHAR_rev1  = Regexp.union(QUOTED_CHAR_safe, QUOTED_CHAR_esc)
        QUOTED_CHAR_rev2  = Regexp.union(QUOTED_CHAR_rev1,
                                         UTF8_2, UTF8_3, UTF8_4)
        QUOTED_rev1       = /"(#{QUOTED_CHAR_rev1}*)"/n
        QUOTED_rev2       = /"(#{QUOTED_CHAR_rev2}*)"/n

        # RFC3501:
        #   text          = 1*TEXT-CHAR
        # RFC9051:
        #   text          = 1*(TEXT-CHAR / UTF8-2 / UTF8-3 / UTF8-4)
        #                     ; Non-ASCII text can only be returned
        #                     ; after ENABLE IMAP4rev2 command
        TEXT_rev1         = /#{TEXT_CHAR}+/
        TEXT_rev2         = /#{Regexp.union TEXT_CHAR, UTF8_2, UTF8_3, UTF8_4}+/

        # tagged-label-fchar = ALPHA / "-" / "_" / "."
        TAGGED_LABEL_FCHAR   = /[a-zA-Z\-_.]/n
        # tagged-label-char  = tagged-label-fchar / DIGIT / ":"
        TAGGED_LABEL_CHAR    = /[a-zA-Z\-_.0-9:]*/n
        # tagged-ext-label   = tagged-label-fchar *tagged-label-char
        #                      ; Is a valid RFC 3501 "atom".
        TAGGED_EXT_LABEL     = /#{TAGGED_LABEL_FCHAR}#{TAGGED_LABEL_CHAR}*/n

        # RFC3501:
        #   literal          = "{" number "}" CRLF *CHAR8
        #                        ; Number represents the number of CHAR8s
        # RFC9051:
        #   literal          = "{" number64 ["+"] "}" CRLF *CHAR8
        #                        ; <number64> represents the number of CHAR8s.
        #                        ; A non-synchronizing literal is distinguished
        #                        ; from a synchronizing literal by the presence of
        #                        ; "+" before the closing "}".
        #                        ; Non-synchronizing literals are not allowed when
        #                        ; sent from server to the client.
        LITERAL              = /\{(\d+)\}\r\n/n

        module_function

        def unescape_quoted!(quoted)
          quoted
            &.gsub!(/\\(#{QUOTED_SPECIALS})/n, "\\1")
            &.force_encoding("UTF-8")
        end

        def unescape_quoted(quoted)
          quoted
            &.gsub(/\\(#{QUOTED_SPECIALS})/n, "\\1")
            &.force_encoding("UTF-8")
        end

      end

      # the default, used in most places
      BEG_REGEXP = /\G(?:\
(?# 1:  SPACE   )( )|\
(?# 2:  ATOM prefixed with a compatible subtype)\
((?:\
(?# 3:  NIL     )(NIL)|\
(?# 4:  NUMBER  )(\d+)|\
(?# 5:  PLUS    )(\+))\
(?# 6:  ATOM remaining after prefix )(#{Patterns::ATOMISH})?\
(?# This enables greedy alternation without lookahead, in linear time.)\
)|\
(?# Also need to check for ATOM without a subtype prefix.)\
(?# 7:  ATOM    )(#{Patterns::ATOMISH})|\
(?# 8:  QUOTED  )#{Patterns::QUOTED_rev2}|\
(?# 9: LPAR    )(\()|\
(?# 10: RPAR    )(\))|\
(?# 11: BSLASH  )(\\)|\
(?# 12: STAR    )(\*)|\
(?# 13: LBRA    )(\[)|\
(?# 14: RBRA    )(\])|\
(?# 15: LITERAL )#{Patterns::LITERAL}|\
(?# 16: PERCENT )(%)|\
(?# 17: CRLF    )(\r\n)|\
(?# 18: EOF     )(\z))/ni

      # envelope, body(structure), namespaces
      DATA_REGEXP = /\G(?:\
(?# 1:  SPACE   )( )|\
(?# 2:  NIL     )(NIL)|\
(?# 3:  NUMBER  )(\d+)|\
(?# 4:  QUOTED  )#{Patterns::QUOTED_rev2}|\
(?# 5:  LITERAL )#{Patterns::LITERAL}|\
(?# 6:  LPAR    )(\()|\
(?# 7:  RPAR    )(\)))/ni

      # text, after 'resp-text-code "]"'
      TEXT_REGEXP = /\G(#{Patterns::TEXT_rev2})/n

      # resp-text-code, after 'atom SP'
      CTEXT_REGEXP = /\G(#{Patterns::CODE_TEXT})/n

      Token = Struct.new(:symbol, :value)

      def_char_matchers :SP,   " ", :T_SPACE
      def_char_matchers :PLUS, "+", :T_PLUS
      def_char_matchers :STAR, "*", :T_STAR

      def_char_matchers :lpar, "(", :T_LPAR
      def_char_matchers :rpar, ")", :T_RPAR

      def_char_matchers :lbra, "[", :T_LBRA
      def_char_matchers :rbra, "]", :T_RBRA

      # valid number ranges are not enforced by parser
      #   number          = 1*DIGIT
      #                       ; Unsigned 32-bit integer
      #                       ; (0 <= n < 4,294,967,296)
      def_token_matchers :number, T_NUMBER, coerce: Integer

      def_token_matchers :quoted, T_QUOTED

      #   string          = quoted / literal
      def_token_matchers :string,  T_QUOTED, T_LITERAL

      # use where string represents "LABEL" values
      def_token_matchers :case_insensitive__string,
                         T_QUOTED, T_LITERAL,
                         send: :upcase

      # n.b: NIL? and NIL! return the "NIL" atom string (truthy) on success.
      # NIL? returns nil when it does *not* match
      def_token_matchers :NIL, T_NIL

      # In addition to explicitly uses of +tagged-ext-label+, use this to match
      # keywords when the grammar has not provided any extension syntax.
      #
      # Do *not* use this for labels where the grammar specifies extensions
      # can be +atom+, even if all currently defined labels would match.  For
      # example response codes in +resp-text-code+.
      #
      #   tagged-ext-label    = tagged-label-fchar *tagged-label-char
      #                         ; Is a valid RFC 3501 "atom".
      #   tagged-label-fchar  = ALPHA / "-" / "_" / "."
      #   tagged-label-char   = tagged-label-fchar / DIGIT / ":"
      #
      # TODO: add to lexer and only match tagged-ext-label
      def_token_matchers :tagged_ext_label, T_ATOM, T_NIL, send: :upcase

      def_token_matchers :CRLF, T_CRLF
      def_token_matchers :EOF,  T_EOF

      # atom            = 1*ATOM-CHAR
      # ATOM-CHAR       = <any CHAR except atom-specials>
      ATOM_TOKENS = [T_ATOM, T_NUMBER, T_NIL, T_LBRA, T_PLUS]

      # ASTRING-CHAR    = ATOM-CHAR / resp-specials
      # resp-specials   = "]"
      ASTRING_CHARS_TOKENS = [*ATOM_TOKENS, T_RBRA].freeze

      ASTRING_TOKENS = [T_QUOTED, *ASTRING_CHARS_TOKENS, T_LITERAL].freeze

      # tag             = 1*<any ASTRING-CHAR except "+">
      TAG_TOKENS = (ASTRING_CHARS_TOKENS - [T_PLUS]).freeze

      # TODO: handle atom, astring_chars, and tag entirely inside the lexer
      def atom;          combine_adjacent(*ATOM_TOKENS)          end
      def astring_chars; combine_adjacent(*ASTRING_CHARS_TOKENS) end
      def tag;           combine_adjacent(*TAG_TOKENS)           end

      # the #accept version of #atom
      def atom?; -combine_adjacent(*ATOM_TOKENS) if lookahead?(*ATOM_TOKENS) end

      # Returns <tt>atom.upcase</tt>
      def case_insensitive__atom; -combine_adjacent(*ATOM_TOKENS).upcase end

      # Returns <tt>atom?&.upcase</tt>
      def case_insensitive__atom?
        -combine_adjacent(*ATOM_TOKENS).upcase if lookahead?(*ATOM_TOKENS)
      end

      #   astring         = 1*ASTRING-CHAR / string
      def astring
        lookahead?(*ASTRING_CHARS_TOKENS) ? astring_chars : string
      end

      def astring?
        lookahead?(*ASTRING_CHARS_TOKENS) ? astring_chars : string?
      end

      # Use #label or #label_in to assert specific known labels
      # (+tagged-ext-label+ only, not +atom+).
      def label(word)
        (val = tagged_ext_label) == word and return val
        parse_error("unexpected atom %p, expected %p instead", val, word)
      end

      # Use #label or #label_in to assert specific known labels
      # (+tagged-ext-label+ only, not +atom+).
      def label_in(*labels)
        lbl = tagged_ext_label and labels.include?(lbl) and return lbl
        parse_error("unexpected atom %p, expected one of %s instead",
                    lbl, labels.join(" or "))
      end

      # expects "OK" or "PREAUTH" and raises InvalidResponseError on failure
      def resp_cond_auth__name
        lbl = tagged_ext_label and AUTH_CONDS.include? lbl and return lbl
        raise InvalidResponseError, "bad response type %p, expected %s" % [
          lbl, AUTH_CONDS.join(" or ")
        ]
      end

      # expects "OK" or "NO" or "BAD" and raises InvalidResponseError on failure
      def resp_cond_state__name
        lbl = tagged_ext_label and RESP_COND_STATES.include? lbl and return lbl
        raise InvalidResponseError, "bad response type %p, expected %s" % [
          lbl, RESP_COND_STATES.join(" or ")
        ]
      end

      #   nstring         = string / nil
      def nstring
        NIL? ? nil : string
      end

      def nquoted
        NIL? ? nil : quoted
      end

      # use where nstring represents "LABEL" values
      def case_insensitive__nstring
        NIL? ? nil : case_insensitive__string
      end

      # valid number ranges are not enforced by parser
      #   number64        = 1*DIGIT
      #                       ; Unsigned 63-bit integer
      #                       ; (0 <= n <= 9,223,372,036,854,775,807)
      alias number64    number
      alias number64?   number?

      # valid number ranges are not enforced by parser
      #   nz-number       = digit-nz *DIGIT
      #                       ; Non-zero unsigned 32-bit integer
      #                       ; (0 < n < 4,294,967,296)
      alias nz_number   number
      alias nz_number?  number?

      # valid number ranges are not enforced by parser
      #   nz-number64     = digit-nz *DIGIT
      #                       ; Unsigned 63-bit integer
      #                       ; (0 < n <= 9,223,372,036,854,775,807)
      alias nz_number64 nz_number

      # valid number ranges are not enforced by parser
      #      uniqueid        = nz-number
      #                          ; Strictly ascending
      alias uniqueid    nz_number

      # [RFC3501 & RFC9051:]
      #   response        = *(continue-req / response-data) response-done
      #
      # For simplicity, response isn't interpreted as the combination of the
      # three response types, but instead represents any individual server
      # response.  Our simplified interpretation is defined as:
      #   response        = continue-req | response_data | response-tagged
      #
      # n.b: our "response-tagged" definition parses "greeting" too.
      def response
        resp = case lookahead!(T_PLUS, T_STAR, *TAG_TOKENS).symbol
               when T_PLUS then continue_req
               when T_STAR then response_data
               else             response_tagged
               end
        accept_spaces # QUIRKY: Ignore trailing space (MS Exchange Server?)
        CRLF!
        EOF!
        resp
      end

      # RFC3501 & RFC9051:
      #   continue-req    = "+" SP (resp-text / base64) CRLF
      #
      # n.b: base64 is valid resp-text.  And in the spirit of RFC9051 Appx E 23
      # (and to workaround existing servers), we use the following grammar:
      #
      #   continue-req    = "+" (SP (resp-text)) CRLF
      def continue_req
        PLUS!
        ContinuationRequest.new(SP? ? resp_text : ResponseText::EMPTY, @str)
      end

      RE_RESPONSE_TYPE = /\G(?:\d+ )?(?<type>#{Patterns::TAGGED_EXT_LABEL})/n

      # [RFC3501:]
      #   response-data    = "*" SP (resp-cond-state / resp-cond-bye /
      #                      mailbox-data / message-data / capability-data) CRLF
      # [RFC4466:]
      #   response-data    = "*" SP response-payload CRLF
      #   response-payload = resp-cond-state / resp-cond-bye /
      #                       mailbox-data / message-data / capability-data
      # RFC5161 (ENABLE capability):
      #   response-data    =/ "*" SP enable-data CRLF
      # RFC5255 (LANGUAGE capability)
      #   response-payload =/ language-data
      # RFC5255 (I18NLEVEL=1 and I18NLEVEL=2 capabilities)
      #   response-payload =/ comparator-data
      # [RFC9051:]
      #   response-data    = "*" SP (resp-cond-state / resp-cond-bye /
      #                      mailbox-data / message-data / capability-data /
      #                      enable-data) CRLF
      #
      # [merging in greeting and response-fatal:]
      #   greeting         =  "*" SP (resp-cond-auth / resp-cond-bye) CRLF
      #   response-fatal   =  "*" SP resp-cond-bye CRLF
      #   response-data    =/ "*" SP (resp-cond-auth / resp-cond-bye) CRLF
      # [removing duplicates, this is simply]
      #   response-payload =/ resp-cond-auth
      #
      # TODO: remove resp-cond-auth and handle greeting separately
      def response_data
        STAR!; SP!
        m = peek_re(RE_RESPONSE_TYPE) or parse_error("unparsable response")
        case m["type"].upcase
        when "OK"         then resp_cond_state__untagged # RFC3501, RFC9051
        when "FETCH"      then message_data__fetch       # RFC3501, RFC9051
        when "EXPUNGE"    then message_data__expunge     # RFC3501, RFC9051
        when "EXISTS"     then mailbox_data__exists      # RFC3501, RFC9051
        when "ESEARCH"    then esearch_response          # RFC4731, RFC9051, etc
        when "VANISHED"   then expunged_resp             # RFC7162
        when "UIDFETCH"   then uidfetch_resp             # (draft) UIDONLY
        when "SEARCH"     then mailbox_data__search      # RFC3501 (obsolete)
        when "CAPABILITY" then capability_data__untagged # RFC3501, RFC9051
        when "FLAGS"      then mailbox_data__flags       # RFC3501, RFC9051
        when "LIST"       then mailbox_data__list        # RFC3501, RFC9051
        when "STATUS"     then mailbox_data__status      # RFC3501, RFC9051
        when "NAMESPACE"  then namespace_response        # RFC2342, RFC9051
        when "ENABLED"    then enable_data               # RFC5161, RFC9051
        when "BAD"        then resp_cond_state__untagged # RFC3501, RFC9051
        when "NO"         then resp_cond_state__untagged # RFC3501, RFC9051
        when "PREAUTH"    then resp_cond_auth            # RFC3501, RFC9051
        when "BYE"        then resp_cond_bye             # RFC3501, RFC9051
        when "RECENT"     then mailbox_data__recent      # RFC3501 (obsolete)
        when "SORT"       then sort_data                 # RFC5256, RFC7162
        when "THREAD"     then thread_data               # RFC5256
        when "QUOTA"      then quota_response            # RFC2087, RFC9208
        when "QUOTAROOT"  then quotaroot_response        # RFC2087, RFC9208
        when "ID"         then id_response               # RFC2971
        when "ACL"        then acl_data                  # RFC4314
        when "LISTRIGHTS" then listrights_data           # RFC4314
        when "MYRIGHTS"   then myrights_data             # RFC4314
        when "METADATA"   then metadata_resp             # RFC5464
        when "LANGUAGE"   then language_data             # RFC5255
        when "COMPARATOR" then comparator_data           # RFC5255
        when "CONVERTED"  then message_data__converted   # RFC5259
        when "LSUB"       then mailbox_data__lsub        # RFC3501 (obsolete)
        when "XLIST"      then mailbox_data__xlist       # deprecated
        when "NOOP"       then response_data__noop
        else                   response_data__unhandled
        end
      end

      def response_data__unhandled(klass = UntaggedResponse)
        num  = number?;          SP?
        type = tagged_ext_label; SP?
        text = remaining_unparsed
        data =
          if num && text then UnparsedNumericResponseData.new(num, text)
          elsif     text then UnparsedData.new(text)
          else                num
          end
        klass.new(type, data, @str)
      end

      # reads all the way up until CRLF
      def remaining_unparsed
        str = @str[@pos...-2] and @pos += str.bytesize
        str&.empty? ? nil : str
      end

      def response_data__ignored; response_data__unhandled(IgnoredResponse) end
      alias response_data__noop     response_data__ignored

      alias esearch_response        response_data__unhandled
      alias expunged_resp           response_data__unhandled
      alias uidfetch_resp           response_data__unhandled
      alias listrights_data         response_data__unhandled
      alias myrights_data           response_data__unhandled
      alias metadata_resp           response_data__unhandled
      alias language_data           response_data__unhandled
      alias comparator_data         response_data__unhandled
      alias message_data__converted response_data__unhandled

      # RFC3501 & RFC9051:
      #   response-tagged = tag SP resp-cond-state CRLF
      #
      #   resp-cond-state = ("OK" / "NO" / "BAD") SP resp-text
      #                       ; Status condition
      #
      #   tag             = 1*<any ASTRING-CHAR except "+">
      def response_tagged
        tag  = tag();                 SP!
        name = resp_cond_state__name; SP!
        TaggedResponse.new(tag, name, resp_text, @str)
      end

      # RFC3501 & RFC9051:
      #   resp-cond-state  = ("OK" / "NO" / "BAD") SP resp-text
      def resp_cond_state__untagged
        name = resp_cond_state__name; SP!
        UntaggedResponse.new(name, resp_text, @str)
      end

      #   resp-cond-auth   = ("OK" / "PREAUTH") SP resp-text
      def resp_cond_auth
        name = resp_cond_auth__name; SP!
        UntaggedResponse.new(name, resp_text, @str)
      end

      #   resp-cond-bye    = "BYE" SP resp-text
      def resp_cond_bye
        name = label(BYE); SP!
        UntaggedResponse.new(name, resp_text, @str)
      end

      #   message-data    = nz-number SP ("EXPUNGE" / ("FETCH" SP msg-att))
      def message_data__fetch
        seq  = nz_number;     SP!
        name = label "FETCH"; SP!
        data = FetchData.new(seq, msg_att(seq))
        UntaggedResponse.new(name, data, @str)
      end

      def response_data__simple_numeric
        data = nz_number; SP!
        name = tagged_ext_label
        UntaggedResponse.new(name, data, @str)
      end

      alias message_data__expunge response_data__simple_numeric
      alias mailbox_data__exists  response_data__simple_numeric
      alias mailbox_data__recent  response_data__simple_numeric

      # RFC3501 & RFC9051:
      #   msg-att         = "(" (msg-att-dynamic / msg-att-static)
      #                      *(SP (msg-att-dynamic / msg-att-static)) ")"
      #
      #   msg-att-dynamic = "FLAGS" SP "(" [flag-fetch *(SP flag-fetch)] ")"
      # RFC5257 (ANNOTATE extension):
      #   msg-att-dynamic =/ "ANNOTATION" SP
      #                        ( "(" entry-att *(SP entry-att) ")" /
      #                          "(" entry *(SP entry) ")" )
      # RFC7162 (CONDSTORE extension):
      #   msg-att-dynamic =/ fetch-mod-resp
      #   fetch-mod-resp  = "MODSEQ" SP "(" permsg-modsequence ")"
      # RFC8970 (PREVIEW extension):
      #   msg-att-dynamic =/ "PREVIEW" SP nstring
      #
      # RFC3501:
      #   msg-att-static  = "ENVELOPE" SP envelope /
      #                     "INTERNALDATE" SP date-time /
      #                     "RFC822" [".HEADER" / ".TEXT"] SP nstring /
      #                     "RFC822.SIZE" SP number /
      #                     "BODY" ["STRUCTURE"] SP body /
      #                     "BODY" section ["<" number ">"] SP nstring /
      #                     "UID" SP uniqueid
      # RFC3516 (BINARY extension):
      #   msg-att-static  =/ "BINARY" section-binary SP (nstring / literal8)
      #                    / "BINARY.SIZE" section-binary SP number
      # RFC8514 (SAVEDATE extension):
      #   msg-att-static  =/ "SAVEDATE" SP (date-time / nil)
      # RFC8474 (OBJECTID extension):
      #   msg-att-static =/ fetch-emailid-resp / fetch-threadid-resp
      #   fetch-emailid-resp  = "EMAILID" SP "(" objectid ")"
      #   fetch-threadid-resp = "THREADID" SP ( "(" objectid ")" / nil )
      # RFC9051:
      #   msg-att-static  = "ENVELOPE" SP envelope /
      #                     "INTERNALDATE" SP date-time /
      #                     "RFC822.SIZE" SP number64 /
      #                     "BODY" ["STRUCTURE"] SP body /
      #                     "BODY" section ["<" number ">"] SP nstring /
      #                     "BINARY" section-binary SP (nstring / literal8) /
      #                     "BINARY.SIZE" section-binary SP number /
      #                     "UID" SP uniqueid
      #
      # Re https://www.rfc-editor.org/errata/eid7246, I'm adding "offset" to the
      # official "BINARY" ABNF, like so:
      #
      #   msg-att-static   =/ "BINARY" section-binary ["<" number ">"] SP
      #                       (nstring / literal8)
      def msg_att(n)
        lpar
        attr = {}
        while true
          name = msg_att__label; SP!
          val =
            case name
            when "UID"                  then uniqueid
            when "FLAGS"                then flag_list
            when "BODY"                 then body
            when /\ABODY\[/ni           then nstring
            when "BODYSTRUCTURE"        then body
            when "ENVELOPE"             then envelope
            when "INTERNALDATE"         then date_time
            when "RFC822.SIZE"          then number64
            when "RFC822"               then nstring            # not in rev2
            when "RFC822.HEADER"        then nstring            # not in rev2
            when "RFC822.TEXT"          then nstring            # not in rev2
            when "MODSEQ"               then parens__modseq     # CONDSTORE
            else parse_error("unknown attribute `%s' for {%d}", name, n)
            end
          attr[name] = val
          break unless SP?
          break if lookahead_rpar?
        end
        rpar
        attr
      end

      # appends "[section]" and "<partial>" to the base label
      def msg_att__label
        case (name = tagged_ext_label)
        when /\A(?:RFC822(?:\.HEADER|\.TEXT)?)\z/ni
          # ignoring "[]" fixes https://bugs.ruby-lang.org/issues/5620
          lbra? and rbra
        when "BODY"
          peek_lbra? and name << section and
            peek_str?("<") and name << atom # partial
        end
        name
      end

      def envelope
        @lex_state = EXPR_DATA
        token = lookahead
        if token.symbol == T_NIL
          shift_token
          result = nil
        else
          match(T_LPAR)
          date = nstring
          match(T_SPACE)
          subject = nstring
          match(T_SPACE)
          from = address_list
          match(T_SPACE)
          sender = address_list
          match(T_SPACE)
          reply_to = address_list
          match(T_SPACE)
          to = address_list
          match(T_SPACE)
          cc = address_list
          match(T_SPACE)
          bcc = address_list
          match(T_SPACE)
          in_reply_to = nstring
          match(T_SPACE)
          message_id = nstring
          match(T_RPAR)
          result = Envelope.new(date, subject, from, sender, reply_to,
                                to, cc, bcc, in_reply_to, message_id)
        end
        @lex_state = EXPR_BEG
        return result
      end

      #   date-time       = DQUOTE date-day-fixed "-" date-month "-" date-year
      #                     SP time SP zone DQUOTE
      alias date_time quoted
      alias ndatetime nquoted

      # RFC-3501 & RFC-9051:
      #   body            = "(" (body-type-1part / body-type-mpart) ")"
      def body
        @lex_state = EXPR_DATA
        lpar; result = peek_lpar? ? body_type_mpart : body_type_1part; rpar
        result
      ensure
        @lex_state = EXPR_BEG
      end
      alias lookahead_body? lookahead_lpar?

      # RFC-3501 & RFC9051:
      #   body-type-1part = (body-type-basic / body-type-msg / body-type-text)
      #                     [SP body-ext-1part]
      def body_type_1part
        # This regexp peek is a performance optimization.
        # The lookahead fallback would work fine too.
        m = peek_re(/\G(?:
            (?<TEXT>     "TEXT"    \s "[^"]+"             )
            |(?<MESSAGE> "MESSAGE" \s "(?:RFC822|GLOBAL)" )
            |(?<BASIC>   "[^"]+"   \s "[^"]+"             )
            |(?<MIXED>   "MIXED"                          )
           )/nix)
        choice = m&.named_captures&.compact&.keys&.first
        # In practice, the following line should never be used. But the ABNF
        # *does* allow literals, and this will handle them.
        choice ||= lookahead_case_insensitive__string!
        case choice
        when "BASIC"   then body_type_basic # => BodyTypeBasic
        when "MESSAGE" then body_type_msg   # => BodyTypeMessage | BodyTypeBasic
        when "TEXT"    then body_type_text  # => BodyTypeText
        when "MIXED"   then body_type_mixed # => BodyTypeMultipart (server bug)
        else                body_type_basic # might be a bug; server's or ours?
        end
      end

      # RFC-3501 & RFC9051:
      #   body-type-basic = media-basic SP body-fields
      def body_type_basic
        type = media_basic # n.b. "basic" type isn't enforced here
        if lookahead_rpar? then return BodyTypeBasic.new(*type) end # invalid
        SP!;    flds = body_fields
        SP? and exts = body_ext_1part
        BodyTypeBasic.new(*type, *flds, *exts)
      end

      # RFC-3501 & RFC-9051:
      #   body-type-text  = media-text SP body-fields SP body-fld-lines
      def body_type_text
        type = media_text
        SP!;   flds  = body_fields
        SP!;   lines = body_fld_lines
        SP? and exts = body_ext_1part
        BodyTypeText.new(*type, *flds, lines, *exts)
      end

      # RFC-3501 & RFC-9051:
      #   body-type-msg   = media-message SP body-fields SP envelope
      #                     SP body SP body-fld-lines
      def body_type_msg
        # n.b. "message/rfc822" type isn't enforced here
        type = media_message
        SP!; flds = body_fields

        # Sometimes servers send body-type-basic when body-type-msg should be.
        # E.g: when a message/rfc822 part has "Content-Disposition: attachment".
        #
        # * SP "("     --> SP envelope       --> continue as body-type-msg
        # * ")"        --> no body-ext-1part --> completed body-type-basic
        # * SP nstring --> SP body-fld-md5
        #              --> SP body-ext-1part --> continue as body-type-basic
        #
        # It's probably better to return BodyTypeBasic---even for
        # "message/rfc822"---than BodyTypeMessage with invalid fields.
        unless peek_str?(" (")
          SP? and exts = body_ext_1part
          return BodyTypeBasic.new(*type, *flds, *exts)
        end

        SP!; env   = envelope
        SP!; bdy   = body
        SP!; lines = body_fld_lines
        SP? and exts = body_ext_1part
        BodyTypeMessage.new(*type, *flds, env, bdy, lines, *exts)
      end

      # This is a malformed body-type-mpart with no subparts.
      def body_type_mixed
        # warn "malformed body-type-mpart: multipart/mixed with no parts."
        type = media_subtype # => "MIXED"
        SP? and exts = body_ext_mpart
        BodyTypeMultipart.new("MULTIPART", type, nil, *exts)
      end

      # RFC-3501 & RFC-9051:
      #   body-type-mpart = 1*body SP media-subtype
      #                     [SP body-ext-mpart]
      def body_type_mpart
        parts = [body]; parts << body until SP?; msubtype = media_subtype
        SP? and exts = body_ext_mpart
        BodyTypeMultipart.new("MULTIPART", msubtype, parts, *exts)
      end

      # n.b. this handles both type and subtype
      #
      # RFC-3501 vs RFC-9051:
      #   media-basic     = ((DQUOTE ("APPLICATION" / "AUDIO" / "IMAGE" /
      #                     "MESSAGE" /
      #                     "VIDEO") DQUOTE) / string) SP media-subtype
      #   media-basic     = ((DQUOTE ("APPLICATION" / "AUDIO" / "IMAGE" /
      #                     "FONT" / "MESSAGE" / "MODEL" /
      #                     "VIDEO") DQUOTE) / string) SP media-subtype
      #
      #   media-message   = DQUOTE "MESSAGE" DQUOTE SP
      #                     DQUOTE "RFC822" DQUOTE
      #   media-message   = DQUOTE "MESSAGE" DQUOTE SP
      #                     DQUOTE ("RFC822" / "GLOBAL") DQUOTE
      #
      # RFC-3501 & RFC-9051:
      #   media-text      = DQUOTE "TEXT" DQUOTE SP media-subtype
      #   media-subtype   = string
      def media_type
        mtype = case_insensitive__string
        SP? or return mtype, nil # ??? quirky!
        msubtype = media_subtype
        return mtype, msubtype
      end

      # TODO: check types
      alias media_basic   media_type # */* --- catchall
      alias media_message media_type # message/rfc822, message/global
      alias media_text    media_type # text/*

      alias media_subtype case_insensitive__string

      # RFC-3501 & RFC-9051:
      #   body-fields     = body-fld-param SP body-fld-id SP body-fld-desc SP
      #                     body-fld-enc SP body-fld-octets
      def body_fields
        fields = []
        fields << body_fld_param; SP!
        fields << body_fld_id;    SP!
        fields << body_fld_desc;  SP!
        fields << body_fld_enc;   SP!
        fields << body_fld_octets
        fields
      end

      # RFC3501, RFC9051:
      # body-fld-param  = "(" string SP string *(SP string SP string) ")" / nil
      def body_fld_param
        return if NIL?
        param = {}
        lpar
        name = case_insensitive__string; SP!; param[name] = string
        while SP?
          name = case_insensitive__string; SP!; param[name] = string
        end
        rpar
        param
      end

      # RFC2060
      #   body_ext_1part  ::= body_fld_md5 [SPACE body_fld_dsp
      #                       [SPACE body_fld_lang
      #                       [SPACE 1#body_extension]]]
      #                       ;; MUST NOT be returned on non-extensible
      #                       ;; "BODY" fetch
      # RFC3501 & RFC9051
      #   body-ext-1part  = body-fld-md5 [SP body-fld-dsp [SP body-fld-lang
      #                     [SP body-fld-loc *(SP body-extension)]]]
      #                       ; MUST NOT be returned on non-extensible
      #                       ; "BODY" fetch
      def body_ext_1part
        fields = [];          fields << body_fld_md5
        SP? or return fields; fields << body_fld_dsp
        SP? or return fields; fields << body_fld_lang
        SP? or return fields; fields << body_fld_loc
        SP? or return fields; fields << body_extensions
        fields
      end

      # RFC-2060:
      #   body_ext_mpart  = body_fld_param [SP body_fld_dsp SP body_fld_lang
      #                     [SP 1#body_extension]]
      #                       ;; MUST NOT be returned on non-extensible
      #                       ;; "BODY" fetch
      # RFC-3501 & RFC-9051:
      #   body-ext-mpart  = body-fld-param [SP body-fld-dsp [SP body-fld-lang
      #                     [SP body-fld-loc *(SP body-extension)]]]
      #                       ; MUST NOT be returned on non-extensible
      #                       ; "BODY" fetch
      def body_ext_mpart
        fields = [];          fields << body_fld_param
        SP? or return fields; fields << body_fld_dsp
        SP? or return fields; fields << body_fld_lang
        SP? or return fields; fields << body_fld_loc
        SP? or return fields; fields << body_extensions
        fields
      end

      alias body_fld_desc   nstring
      alias body_fld_id     nstring
      alias body_fld_loc    nstring
      alias body_fld_lines  number64 # number in 3501, number64 in 9051
      alias body_fld_md5    nstring
      alias body_fld_octets number

      # RFC-3501 & RFC-9051:
      #   body-fld-enc    = (DQUOTE ("7BIT" / "8BIT" / "BINARY" / "BASE64"/
      #                     "QUOTED-PRINTABLE") DQUOTE) / string
      alias body_fld_enc case_insensitive__string

      #   body-fld-dsp    = "(" string SP body-fld-param ")" / nil
      def body_fld_dsp
        return if NIL?
        lpar; dsp_type = case_insensitive__string
        SP!;  param    = body_fld_param
        rpar
        ContentDisposition.new(dsp_type, param)
      end

      #   body-fld-lang   = nstring / "(" string *(SP string) ")"
      def body_fld_lang
        if lpar?
          result = [case_insensitive__string]
          result << case_insensitive__string while SP?
          rpar
          result
        else
          case_insensitive__nstring
        end
      end

      #   body-extension *(SP body-extension)
      def body_extensions
        result = []
        result << body_extension; while SP? do result << body_extension end
        result
      end

      #   body-extension  = nstring / number / number64 /
      #                      "(" body-extension *(SP body-extension) ")"
      #                       ; Future expansion.  Client implementations
      #                       ; MUST accept body-extension fields.  Server
      #                       ; implementations MUST NOT generate
      #                       ; body-extension fields except as defined by
      #                       ; future Standard or Standards Track
      #                       ; revisions of this specification.
      def body_extension
        if (uint = number64?) then uint
        elsif lpar?           then exts = body_extensions; rpar; exts
        else                       nstring
        end
      end

      # section         = "[" [section-spec] "]"
      def section
        str = +lbra
        str << section_spec unless peek_rbra?
        str << rbra
      end

      # section-spec    = section-msgtext / (section-part ["." section-text])
      # section-msgtext = "HEADER" /
      #                   "HEADER.FIELDS" [".NOT"] SP header-list /
      #                   "TEXT"
      #                     ; top-level or MESSAGE/RFC822 or
      #                     ; MESSAGE/GLOBAL part
      # section-part    = nz-number *("." nz-number)
      #                     ; body part reference.
      #                     ; Allows for accessing nested body parts.
      # section-text    = section-msgtext / "MIME"
      #                     ; text other than actual body part (headers,
      #                     ; etc.)
      #
      # n.b: we could "cheat" here and just grab all text inside the brackets,
      # but literals would need special treatment.
      def section_spec
        str = "".b
        str << atom # grabs everything up to "SP header-list" or "]"
        str << " " << header_list if SP?
        str
      end

      # header-list     = "(" header-fld-name *(SP header-fld-name) ")"
      def header_list
        str = +""
        str << lpar << header_fld_name
        str << " "  << header_fld_name while SP?
        str << rpar
      end

      # RFC3501 & RFC9051:
      #   header-fld-name = astring
      #
      # NOTE: Previously, Net::IMAP recreated the raw original source string.
      # Now, it grabs the raw encoded value using @str and @pos.  A future
      # version may simply return the decoded astring value.  Although that is
      # technically incompatible, it should almost never make a difference: all
      # standard header field names are valid atoms:
      #
      # https://www.iana.org/assignments/message-headers/message-headers.xhtml
      #
      # Although RFC3501 allows any astring, RFC5322-valid header names are one
      # or more of the printable US-ASCII characters, except SP and colon.  So
      # empty string isn't valid, and literals aren't needed and should not be
      # used.  This is explicitly unchanged by [I18N-HDRS] (RFC6532).
      #
      # RFC5233:
      #     optional-field  =   field-name ":" unstructured CRLF
      #     field-name      =   1*ftext
      #     ftext           =   %d33-57 /          ; Printable US-ASCII
      #                         %d59-126           ;  characters not including
      #                                            ;  ":".
      def header_fld_name
        assert_no_lookahead
        start = @pos
        astring
        @str[start...@pos - 1]
      end

      # mailbox-data    =  "FLAGS" SP flag-list / "LIST" SP mailbox-list /
      #                    "LSUB" SP mailbox-list / "SEARCH" *(SP nz-number) /
      #                    "STATUS" SP mailbox SP "(" [status-att-list] ")" /
      #                    number SP "EXISTS" / number SP "RECENT"

      def mailbox_data__flags
        name = label("FLAGS")
        SP!
        UntaggedResponse.new(name, flag_list, @str)
      end

      def mailbox_data__list
        name = label_in("LIST", "LSUB", "XLIST")
        SP!
        UntaggedResponse.new(name, mailbox_list, @str)
      end
      alias mailbox_data__lsub  mailbox_data__list
      alias mailbox_data__xlist mailbox_data__list

      def mailbox_list
        attr = flag_list
        match(T_SPACE)
        token = match(T_QUOTED, T_NIL)
        if token.symbol == T_NIL
          delim = nil
        else
          delim = token.value
        end
        match(T_SPACE)
        name = astring
        return MailboxList.new(attr, delim, name)
      end

      def getquota_response
        # If quota never established, get back
        # `NO Quota root does not exist'.
        # If quota removed, get `()' after the
        # folder spec with no mention of `STORAGE'.
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        mailbox = astring
        match(T_SPACE)
        match(T_LPAR)
        token = lookahead
        case token.symbol
        when T_RPAR
          shift_token
          data = MailboxQuota.new(mailbox, nil, nil)
          return UntaggedResponse.new(name, data, @str)
        when T_ATOM
          shift_token
          match(T_SPACE)
          token = match(T_NUMBER)
          usage = token.value
          match(T_SPACE)
          token = match(T_NUMBER)
          quota = token.value
          match(T_RPAR)
          data = MailboxQuota.new(mailbox, usage, quota)
          return UntaggedResponse.new(name, data, @str)
        else
          parse_error("unexpected token %s", token.symbol)
        end
      end

      def getquotaroot_response
        # Similar to getquota, but only admin can use getquota.
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        mailbox = astring
        quotaroots = []
        while true
          token = lookahead
          break unless token.symbol == T_SPACE
          shift_token
          quotaroots.push(astring)
        end
        data = MailboxQuotaRoot.new(mailbox, quotaroots)
        return UntaggedResponse.new(name, data, @str)
      end

      # acl-data        = "ACL" SP mailbox *(SP identifier SP rights)
      def acl_data
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        mailbox = astring
        data = []
        token = lookahead
        if token.symbol == T_SPACE
          shift_token
          while true
            token = lookahead
            case token.symbol
            when T_CRLF
              break
            when T_SPACE
              shift_token
            end
            user = astring
            match(T_SPACE)
            rights = astring
            data.push(MailboxACLItem.new(user, rights, mailbox))
          end
        end
        return UntaggedResponse.new(name, data, @str)
      end

      # RFC3501:
      #   mailbox-data        = "SEARCH" *(SP nz-number) / ...
      # RFC5256: SORT
      #   sort-data           = "SORT" *(SP nz-number)
      # RFC7162: CONDSTORE, QRESYNC
      #   mailbox-data        =/ "SEARCH" [1*(SP nz-number) SP
      #                          search-sort-mod-seq]
      #   sort-data           = "SORT" [1*(SP nz-number) SP
      #                           search-sort-mod-seq]
      #                           ; Updates the SORT response from RFC 5256.
      #   search-sort-mod-seq = "(" "MODSEQ" SP mod-sequence-value ")"
      # RFC9051:
      #   mailbox-data        = obsolete-search-response / ...
      #   obsolete-search-response = "SEARCH" *(SP nz-number)
      def mailbox_data__search
        token = match(T_ATOM)
        name = token.value.upcase
        token = lookahead
        if token.symbol == T_SPACE
          shift_token
          data = []
          while true
            token = lookahead
            case token.symbol
            when T_CRLF
              break
            when T_SPACE
              shift_token
            when T_NUMBER
              data.push(number)
            when T_LPAR
              # TODO: include the MODSEQ value in a response
              shift_token
              match(T_ATOM)
              match(T_SPACE)
              match(T_NUMBER)
              match(T_RPAR)
            end
          end
        else
          data = []
        end
        return UntaggedResponse.new(name, data, @str)
      end
      alias sort_data mailbox_data__search

      def thread_data
        token = match(T_ATOM)
        name = token.value.upcase
        token = lookahead

        if token.symbol == T_SPACE
          threads = []

          while true
            shift_token
            token = lookahead

            case token.symbol
            when T_LPAR
              threads << thread_branch(token)
            when T_CRLF
              break
            end
          end
        else
          # no member
          threads = []
        end

        return UntaggedResponse.new(name, threads, @str)
      end

      def thread_branch(token)
        rootmember = nil
        lastmember = nil

        while true
          shift_token    # ignore first T_LPAR
          token = lookahead

          case token.symbol
          when T_NUMBER
            # new member
            newmember = ThreadMember.new(number, [])
            if rootmember.nil?
              rootmember = newmember
            else
              lastmember.children << newmember
            end
            lastmember = newmember
          when T_SPACE
            # do nothing
          when T_LPAR
            if rootmember.nil?
              # dummy member
              lastmember = rootmember = ThreadMember.new(nil, [])
            end

            lastmember.children << thread_branch(token)
          when T_RPAR
            break
          end
        end

        return rootmember
      end

      def mailbox_data__status
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        mailbox = astring
        match(T_SPACE)
        match(T_LPAR)
        attr = {}
        while true
          token = lookahead
          case token.symbol
          when T_RPAR
            shift_token
            break
          when T_SPACE
            shift_token
          end
          token = match(T_ATOM)
          key = token.value.upcase
          match(T_SPACE)
          val = number
          attr[key] = val
        end
        data = StatusData.new(mailbox, attr)
        return UntaggedResponse.new(name, data, @str)
      end

      # The presence of "IMAP4rev1" or "IMAP4rev2" is unenforced here.
      # The grammar rule is used by both response-data and resp-text-code.
      # But this method only returns UntaggedResponse (response-data).
      #
      # RFC3501:
      #   capability-data  = "CAPABILITY" *(SP capability) SP "IMAP4rev1"
      #                      *(SP capability)
      # RFC9051:
      #   capability-data  = "CAPABILITY" *(SP capability) SP "IMAP4rev2"
      #                      *(SP capability)
      def capability_data__untagged
        UntaggedResponse.new label("CAPABILITY"), capability__list, @str
      end

      # enable-data   = "ENABLED" *(SP capability)
      def enable_data
        UntaggedResponse.new label("ENABLED"), capability__list, @str
      end

      # As a workaround for buggy servers, allow a trailing SP:
      #     *(SP capability) [SP]
      def capability__list
        list = []; while SP? && (capa = capability?) do list << capa end; list
      end

      alias resp_code__capability capability__list

      # capability      = ("AUTH=" auth-type) / atom
      #                     ; New capabilities MUST begin with "X" or be
      #                     ; registered with IANA as standard or
      #                     ; standards-track
      alias capability  case_insensitive__atom
      alias capability? case_insensitive__atom?

      def id_response
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        token = match(T_LPAR, T_NIL)
        if token.symbol == T_NIL
          return UntaggedResponse.new(name, nil, @str)
        else
          data = {}
          while true
            token = lookahead
            case token.symbol
            when T_RPAR
              shift_token
              break
            when T_SPACE
              shift_token
              next
            else
              key = string
              match(T_SPACE)
              val = nstring
              data[key] = val
            end
          end
          return UntaggedResponse.new(name, data, @str)
        end
      end

      # namespace-response = "NAMESPACE" SP namespace
      #                       SP namespace SP namespace
      #                  ; The first Namespace is the Personal Namespace(s).
      #                  ; The second Namespace is the Other Users'
      #                  ; Namespace(s).
      #                  ; The third Namespace is the Shared Namespace(s).
      def namespace_response
        name = label("NAMESPACE")
        @lex_state = EXPR_DATA
        data = Namespaces.new((SP!; namespace),
                              (SP!; namespace),
                              (SP!; namespace))
        UntaggedResponse.new(name, data, @str)
      ensure
        @lex_state = EXPR_BEG
      end

      # namespace         = nil / "(" 1*namespace-descr ")"
      def namespace
        NIL? and return []
        lpar
        list = [namespace_descr]
        list << namespace_descr until rpar?
        list
      end

      # namespace-descr   = "(" string SP
      #                        (DQUOTE QUOTED-CHAR DQUOTE / nil)
      #                         [namespace-response-extensions] ")"
      def namespace_descr
        lpar
        prefix     = string; SP!
        delimiter  = nquoted # n.b: should only accept single char
        extensions = namespace_response_extensions
        rpar
        Namespace.new(prefix, delimiter, extensions)
      end

      # namespace-response-extensions = *namespace-response-extension
      # namespace-response-extension = SP string SP
      #                   "(" string *(SP string) ")"
      def namespace_response_extensions
        data = {}
        while SP?
          name = string; SP!
          lpar
          data[name] ||= []
          data[name] << string
          data[name] << string while SP?
          rpar
        end
        data
      end

      #   TEXT-CHAR       = <any CHAR except CR and LF>
      # RFC3501:
      #   text            = 1*TEXT-CHAR
      # RFC9051:
      #   text            = 1*(TEXT-CHAR / UTF8-2 / UTF8-3 / UTF8-4)
      #                     ; Non-ASCII text can only be returned
      #                     ; after ENABLE IMAP4rev2 command
      def text
        match_re(TEXT_REGEXP, "text")[0].force_encoding("UTF-8")
      end

      # an "accept" versiun of #text
      def text?
        accept_re(TEXT_REGEXP)&.[](0)&.force_encoding("UTF-8")
      end

      # RFC3501:
      #   resp-text       = ["[" resp-text-code "]" SP] text
      # RFC9051:
      #   resp-text       = ["[" resp-text-code "]" SP] [text]
      #
      # We leniently re-interpret this as
      #   resp-text       = ["[" resp-text-code "]" [SP [text]] / [text]
      def resp_text
        if lbra?
          code = resp_text_code; rbra
          ResponseText.new(code, SP? && text? || "")
        else
          ResponseText.new(nil, text? || "")
        end
      end

      # RFC3501 (See https://www.rfc-editor.org/errata/rfc3501):
      #   resp-text-code   = "ALERT" /
      #                      "BADCHARSET" [SP "(" charset *(SP charset) ")" ] /
      #                      capability-data / "PARSE" /
      #                      "PERMANENTFLAGS" SP "(" [flag-perm *(SP flag-perm)] ")" /
      #                      "READ-ONLY" / "READ-WRITE" / "TRYCREATE" /
      #                      "UIDNEXT" SP nz-number / "UIDVALIDITY" SP nz-number /
      #                      "UNSEEN" SP nz-number /
      #                      atom [SP 1*<any TEXT-CHAR except "]">]
      #   capability-data  = "CAPABILITY" *(SP capability) SP "IMAP4rev1"
      #                      *(SP capability)
      #
      # RFC5530:
      #   resp-text-code  =/ "UNAVAILABLE" / "AUTHENTICATIONFAILED" /
      #                     "AUTHORIZATIONFAILED" / "EXPIRED" /
      #                     "PRIVACYREQUIRED" / "CONTACTADMIN" / "NOPERM" /
      #                     "INUSE" / "EXPUNGEISSUED" / "CORRUPTION" /
      #                     "SERVERBUG" / "CLIENTBUG" / "CANNOT" /
      #                     "LIMIT" / "OVERQUOTA" / "ALREADYEXISTS" /
      #                     "NONEXISTENT"
      # RFC9051:
      #   resp-text-code   = "ALERT" /
      #                      "BADCHARSET" [SP "(" charset *(SP charset) ")" ] /
      #                      capability-data / "PARSE" /
      #                      "PERMANENTFLAGS" SP "(" [flag-perm *(SP flag-perm)] ")" /
      #                      "READ-ONLY" / "READ-WRITE" / "TRYCREATE" /
      #                      "UIDNEXT" SP nz-number / "UIDVALIDITY" SP nz-number /
      #                      resp-code-apnd / resp-code-copy / "UIDNOTSTICKY" /
      #                      "UNAVAILABLE" / "AUTHENTICATIONFAILED" /
      #                      "AUTHORIZATIONFAILED" / "EXPIRED" /
      #                      "PRIVACYREQUIRED" / "CONTACTADMIN" / "NOPERM" /
      #                      "INUSE" / "EXPUNGEISSUED" / "CORRUPTION" /
      #                      "SERVERBUG" / "CLIENTBUG" / "CANNOT" /
      #                      "LIMIT" / "OVERQUOTA" / "ALREADYEXISTS" /
      #                      "NONEXISTENT" / "NOTSAVED" / "HASCHILDREN" /
      #                      "CLOSED" /
      #                      "UNKNOWN-CTE" /
      #                      atom [SP 1*<any TEXT-CHAR except "]">]
      #   capability-data  = "CAPABILITY" *(SP capability) SP "IMAP4rev2"
      #                      *(SP capability)
      #
      # RFC4315 (UIDPLUS), RFC9051 (IMAP4rev2):
      #   resp-code-apnd   = "APPENDUID" SP nz-number SP append-uid
      #   resp-code-copy   = "COPYUID" SP nz-number SP uid-set SP uid-set
      #   resp-text-code   =/ resp-code-apnd / resp-code-copy / "UIDNOTSTICKY"
      #
      # RFC7162 (CONDSTORE):
      #   resp-text-code   =/ "HIGHESTMODSEQ" SP mod-sequence-value /
      #                       "NOMODSEQ" /
      #                       "MODIFIED" SP sequence-set
      def resp_text_code
        name = resp_text_code__name
        data =
          case name
          when "CAPABILITY"         then resp_code__capability
          when "PERMANENTFLAGS"     then SP? ? flag_perm__list : []
          when "UIDNEXT"            then SP!; nz_number
          when "UIDVALIDITY"        then SP!; nz_number
          when "UNSEEN"             then SP!; nz_number            # rev1 only
          when "APPENDUID"          then SP!; resp_code_apnd__data # rev2, UIDPLUS
          when "COPYUID"            then SP!; resp_code_copy__data # rev2, UIDPLUS
          when "BADCHARSET"         then SP? ? charset__list : []
          when "ALERT", "PARSE", "READ-ONLY", "READ-WRITE", "TRYCREATE",
            "UNAVAILABLE", "AUTHENTICATIONFAILED", "AUTHORIZATIONFAILED",
            "EXPIRED", "PRIVACYREQUIRED", "CONTACTADMIN", "NOPERM", "INUSE",
            "EXPUNGEISSUED", "CORRUPTION", "SERVERBUG", "CLIENTBUG", "CANNOT",
            "LIMIT", "OVERQUOTA", "ALREADYEXISTS", "NONEXISTENT", "CLOSED",
            "NOTSAVED", "UIDNOTSTICKY", "UNKNOWN-CTE", "HASCHILDREN"
          when "NOMODSEQ"           # CONDSTORE
          else
            SP? and text_chars_except_rbra
          end
        ResponseCode.new(name, data)
      end

      alias resp_text_code__name case_insensitive__atom

      # 1*<any TEXT-CHAR except "]">
      def text_chars_except_rbra
        match_re(CTEXT_REGEXP, '1*<any TEXT-CHAR except "]">')[0]
      end

      # "(" charset *(SP charset) ")"
      def charset__list
        lpar; list = [charset]; while SP? do list << charset end; rpar; list
      end

      # already matched:  "APPENDUID"
      #
      # +UIDPLUS+ ABNF:: https://www.rfc-editor.org/rfc/rfc4315.html#section-4
      #   resp-code-apnd  = "APPENDUID" SP nz-number SP append-uid
      #   append-uid      = uniqueid
      #   append-uid      =/ uid-set
      #                     ; only permitted if client uses [MULTIAPPEND]
      #                     ; to append multiple messages.
      #
      # n.b, uniqueid ⊂ uid-set.  To avoid inconsistent return types, we always
      # match uid_set even if that returns a single-member array.
      #
      def resp_code_apnd__data
        validity = number; SP!
        dst_uids = uid_set # uniqueid ⊂ uid-set
        UIDPlusData.new(validity, nil, dst_uids)
      end

      # already matched:  "COPYUID"
      #
      # resp-code-copy  = "COPYUID" SP nz-number SP uid-set SP uid-set
      def resp_code_copy__data
        validity = number;  SP!
        src_uids = uid_set; SP!
        dst_uids = uid_set
        UIDPlusData.new(validity, src_uids, dst_uids)
      end

      def address_list
        token = lookahead
        if token.symbol == T_NIL
          shift_token
          return nil
        else
          result = []
          match(T_LPAR)
          while true
            token = lookahead
            case token.symbol
            when T_RPAR
              shift_token
              break
            when T_SPACE
              shift_token
            end
            result.push(address)
          end
          return result
        end
      end

      ADDRESS_REGEXP = /\G\
(?# 1: NAME     )(?:NIL|"((?:[^\x80-\xff\x00\r\n"\\]|\\["\\])*)") \
(?# 2: ROUTE    )(?:NIL|"((?:[^\x80-\xff\x00\r\n"\\]|\\["\\])*)") \
(?# 3: MAILBOX  )(?:NIL|"((?:[^\x80-\xff\x00\r\n"\\]|\\["\\])*)") \
(?# 4: HOST     )(?:NIL|"((?:[^\x80-\xff\x00\r\n"\\]|\\["\\])*)")\
\)/ni

      def address
        match(T_LPAR)
        if @str.index(ADDRESS_REGEXP, @pos)
          # address does not include literal.
          @pos = $~.end(0)
          name = $1
          route = $2
          mailbox = $3
          host = $4
          for s in [name, route, mailbox, host]
            Patterns.unescape_quoted! s
          end
        else
          name = nstring
          match(T_SPACE)
          route = nstring
          match(T_SPACE)
          mailbox = nstring
          match(T_SPACE)
          host = nstring
          match(T_RPAR)
        end
        return Address.new(name, route, mailbox, host)
      end

      # flag-list       = "(" [flag *(SP flag)] ")"
      def flag_list
        match_re(Patterns::FLAG_LIST, "flag-list")[1]
          .split(nil)
          .map! { _1.start_with?("\\") ? _1[1..].capitalize.to_sym : _1 }
      end

      #   "(" [flag-perm *(SP flag-perm)] ")"
      def flag_perm__list
        match_re(Patterns::FLAG_PERM_LIST, "PERMANENTFLAGS flag-perm list")[1]
          .split(nil)
          .map! { _1.start_with?("\\") ? _1[1..].capitalize.to_sym : _1 }
      end

      # Not checking for max one mbx-list-sflag in the parser.
      # >>>
      #   mbx-list-flags  = *(mbx-list-oflag SP) mbx-list-sflag
      #                     *(SP mbx-list-oflag) /
      #                     mbx-list-oflag *(SP mbx-list-oflag)
      #   mbx-list-oflag  = "\Noinferiors" / child-mbox-flag /
      #                     "\Subscribed" / "\Remote" / flag-extension
      #                  ; Other flags; multiple from this list are
      #                  ; possible per LIST response, but each flag
      #                  ; can only appear once per LIST response
      #   mbx-list-sflag  = "\NonExistent" / "\Noselect" / "\Marked" /
      #                     "\Unmarked"
      #                  ; Selectability flags; only one per LIST response
      def parens__mbx_list_flags
        match_re(Patterns::MBX_LIST_FLAGS, "mbx-list-flags")[1]
          .split(nil).map! { _1.capitalize.to_sym }
      end

      # See https://www.rfc-editor.org/errata/rfc3501
      #
      # charset = atom / quoted
      def charset; quoted? || atom end

      # RFC7162:
      # mod-sequence-value  = 1*DIGIT
      #                        ;; Positive unsigned 63-bit integer
      #                        ;; (mod-sequence)
      #                        ;; (1 <= n <= 9,223,372,036,854,775,807).
      alias mod_sequence_value nz_number64

      # RFC7162:
      # permsg-modsequence  = mod-sequence-value
      #                        ;; Per-message mod-sequence.
      alias permsg_modsequence mod_sequence_value

      def parens__modseq; lpar; _ = permsg_modsequence; rpar; _ end

      # RFC-4315 (UIDPLUS) or RFC9051 (IMAP4rev2):
      #      uid-set         = (uniqueid / uid-range) *("," uid-set)
      #      uid-range       = (uniqueid ":" uniqueid)
      #                          ; two uniqueid values and all values
      #                          ; between these two regardless of order.
      #                          ; Example: 2:4 and 4:2 are equivalent.
      #      uniqueid        = nz-number
      #                          ; Strictly ascending
      def uid_set
        token = match(T_NUMBER, T_ATOM)
        case token.symbol
        when T_NUMBER then [Integer(token.value)]
        when T_ATOM
          token.value.split(",").flat_map {|range|
            range = range.split(":").map {|uniqueid| Integer(uniqueid) }
            range.size == 1 ? range : Range.new(range.min, range.max).to_a
          }
        end
      end

      def nil_atom
        match(T_NIL)
        return nil
      end

      SPACES_REGEXP = /\G */n

      # The RFC is very strict about this and usually we should be too.
      # But skipping spaces is usually a safe workaround for buggy servers.
      #
      # This advances @pos directly so it's safe before changing @lex_state.
      def accept_spaces
        return false unless SP?
        @str.index(SPACES_REGEXP, @pos) and
          @pos = $~.end(0)
        true
      end

      def next_token
        case @lex_state
        when EXPR_BEG
          if @str.index(BEG_REGEXP, @pos)
            @pos = $~.end(0)
            if $1
              return Token.new(T_SPACE, $+)
            elsif $2 && $6
              # greedily match ATOM, prefixed with NUMBER, NIL, or PLUS.
              return Token.new(T_ATOM, $2)
            elsif $3
              return Token.new(T_NIL, $+)
            elsif $4
              return Token.new(T_NUMBER, $+)
            elsif $5
              return Token.new(T_PLUS, $+)
            elsif $7
              # match ATOM, without a NUMBER, NIL, or PLUS prefix
              return Token.new(T_ATOM, $+)
            elsif $8
              return Token.new(T_QUOTED, Patterns.unescape_quoted($+))
            elsif $9
              return Token.new(T_LPAR, $+)
            elsif $10
              return Token.new(T_RPAR, $+)
            elsif $11
              return Token.new(T_BSLASH, $+)
            elsif $12
              return Token.new(T_STAR, $+)
            elsif $13
              return Token.new(T_LBRA, $+)
            elsif $14
              return Token.new(T_RBRA, $+)
            elsif $15
              len = $+.to_i
              val = @str[@pos, len]
              @pos += len
              return Token.new(T_LITERAL, val)
            elsif $16
              return Token.new(T_PERCENT, $+)
            elsif $17
              return Token.new(T_CRLF, $+)
            elsif $18
              return Token.new(T_EOF, $+)
            else
              parse_error("[Net::IMAP BUG] BEG_REGEXP is invalid")
            end
          else
            @str.index(/\S*/n, @pos)
            parse_error("unknown token - %s", $&.dump)
          end
        when EXPR_DATA
          if @str.index(DATA_REGEXP, @pos)
            @pos = $~.end(0)
            if $1
              return Token.new(T_SPACE, $+)
            elsif $2
              return Token.new(T_NIL, $+)
            elsif $3
              return Token.new(T_NUMBER, $+)
            elsif $4
              return Token.new(T_QUOTED, Patterns.unescape_quoted($+))
            elsif $5
              len = $+.to_i
              val = @str[@pos, len]
              @pos += len
              return Token.new(T_LITERAL, val)
            elsif $6
              return Token.new(T_LPAR, $+)
            elsif $7
              return Token.new(T_RPAR, $+)
            else
              parse_error("[Net::IMAP BUG] DATA_REGEXP is invalid")
            end
          else
            @str.index(/\S*/n, @pos)
            parse_error("unknown token - %s", $&.dump)
          end
        else
          parse_error("invalid @lex_state - %s", @lex_state.inspect)
        end
      end

    end
  end
end
