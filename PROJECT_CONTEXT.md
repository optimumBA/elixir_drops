# elixir_drops - Project Context

## Project Overview

**Mission**: Code snippet sharing platform for Elixir developers with automatic screenshot generation and real-time updates.

**Architecture**: Phoenix LiveView with server-rendered UI, Phoenix contexts pattern, real-time PubSub broadcasting.

**Key Integrations**: GitHub OAuth, AWS S3, FLAME (distributed processing), AppSignal (monitoring).

## Module Directory

### Core Modules

- **ElixirDrops.Accounts**: User authentication and session management via GitHub OAuth
- **ElixirDrops.Drops**: Core business logic for managing code snippets (drops), including CRUD operations, filtering, and broadcasting
- **ElixirDrops.Repo**: Ecto repository for database interactions
- **ElixirDrops.Mailer**: Email delivery infrastructure (using Swoosh)

### Feature Modules

- **ElixirDrops.Drops.DropsBroadcast**: Real-time broadcasting for drop events (creation, screenshot updates)
- **ElixirDrops.Drops.ShortIdGenerator**: Generates unique short IDs for shareable drop URLs
- **ElixirDrops.Drops.Screenshot**: Embedded schema for managing screenshot metadata and status
- **ElixirDrops.Sitemap**: Generates and maintains XML sitemap for SEO
- **ElixirDrops.StructuredData**: Generates JSON-LD structured data for rich snippets
- **ElixirDrops.Search**: Search functionality with PostgreSQL full-text search, suggestions system (2+3 rule), and search history tracking
- **ElixirDropsWeb.DropsBatchCalculator**: Calculates optimal batch sizes for drops based on viewport dimensions (1-5 column layouts)

### Infrastructure Modules

- **ElixirDrops.Workers.ScreenshotGeneratorWorker**: Oban worker for asynchronous screenshot generation using FLAME
- **ElixirDrops.Workers.SitemapGeneratorWorker**: Oban worker for periodic sitemap updates
- **ElixirDrops.S3Helper**: AWS S3 client abstraction for screenshot storage
- **ElixirDrops.Helpers.ScreenshotGeneratorWorkerHelper**: Helper functions for screenshot generation process
- **ElixirDrops.Release**: Production release management with database migration and sanitized dump restoration
- **ElixirDrops.DevAuth**: Development authentication bypass using standard session tokens (route: `/dev/auth/:user_id`)
- **ElixirDrops.MarkdownCache**: ETS-based in-memory cache for markdown content with 5-minute TTL and cache-first patterns
- **ElixirDrops.MarkdownFormatter**: Converts drop data to clean markdown format for LLM consumption
- **ElixirDropsWeb.MarkdownController**: Serves raw markdown at `/d/:short_id.md` and `/index.md` endpoints
- **ElixirDropsWeb.Plugs.MarkdownInterceptor**: Binary pattern matching interceptor for `.md` file extensions in Phoenix routes
- **ElixirDropsWeb.LiveAcceptance**: Browser test database sandbox hook for LiveView + PhoenixTest.Playwright integration

### LiveView Modules

- **DropLive.Index**: Lists drops with real-time updates and masonry layout
- **DropLive.Show**: Displays single drop with screenshot
- **UserDropLive.Index**: User's drops management interface with auto-refresh
- **UserDropLive.FormComponent**: Drop creation/editing form
- **DropsListHelper**: Shared component for drops listing with infinite scroll and dynamic batching

## Tech Stack & Patterns

### Technologies

- **Backend**: Elixir 1.17.1-otp-27, Phoenix 1.7.14, LiveView 1.0.0-rc.1, Ecto SQL 3.10 (PostgreSQL), Oban 2.18
- **Frontend**: Tailwind CSS 3.4.3, esbuild 0.17.11, masonry-layout 4.2.2, imagesloaded 5.0.0, Heroicons
- **Testing**: ExUnit with ExMachina factories, PhoenixTest.Playwright for browser automation with async parallel execution, fixture-based test data

### Key Patterns

- **Context Pattern**: Public APIs for domain operations, cross-context references use aliased names (e.g., `Accounts.User`)
- **LiveView Patterns**: Form components, real-time PubSub updates, cursor-based pagination, stream-based updates for performance
- **Database Patterns**: Binary IDs, embedded schemas (e.g., Screenshot in Drop), unique constraints with indexes, PostgreSQL full-text search with ts_rank
- **Masonry Layout**: Dynamic batch sizing (mobile: 6-12, tablet: 10-20, desktop: 15-40 items), viewport-aware loading
- **Search Suggestions**: 2+3 rule (2 history + 3 popular for auth users, 5 popular for unauth), atomic count increments for popular searches
- **Phoenix Components**: Alphabetical attribute ordering in both `attr` declarations and HEEx component calls for consistency
- **Route Verification**: Hybrid approach - static routes use `~p` sigil, dynamic routes use string interpolation, error testing uses invalid strings
- **Browser Testing**: Domain-based test organization over technology-based separation, real Chrome automation with PhoenixTest.Playwright, async parallel execution with database sandbox integration
- **Terminology Consistency**: Systematic refactoring pattern for UI terminology changes: backend functions → UI text → unit tests, maintaining functionality while updating presentation layer
- **File Extension Routing**: Phoenix interceptor patterns using binary pattern matching for custom file extensions (e.g., `.md`) in routes
- **Content Caching**: ETS-based in-memory caching with TTL expiration and cache-first database patterns for performance optimization
- **LLM Integration**: Markdown export functionality with proper content-type headers and clean formatting for AI consumption

### Routing Architecture

- **Public**: `/` (home), `/d/:short_id` (drop view), `/code/:short_id` (JSON API), `/health`
- **Markdown**: `/index.md` (all drops index), `/d/:short_id.md` (individual drop markdown)
- **Auth**: `/auth/github`, `/auth/github/callback`, `/auth/signout`
- **Protected**: `/profile`, `/profile/drops/new`, `/profile/drops/:id/edit`
- **Pipelines**: `:browser`, `:api`, `:markdown` (minimal pipeline for .md content), `:require_authenticated_user`, `:redirect_if_user_is_authenticated`

## API Contracts

### Context APIs

- **Accounts**: `get_user_by_email/1`, `register_github_user/1`, `generate_user_session_token/1`
- **Drops**: `list_drops/1`, `create_drop/1`, `get_drop_by_short_id!/1`, `broadcast_drop_created/1`, `broadcast_screenshot_generated/1`
- **Search**: `create_search_history/2`, `get_search_suggestions/2`, `track_popular_search/1`, `delete_search_history/2`

### Schema Structure

- **User**: has_many :drops, GitHub profile fields
- **Drop**: belongs_to :user, embeds_one :screenshot, fields: short_id, language, code_snippet, search_vector (tsvector)
- **UserToken**: handles session management
- **SearchHistory**: belongs_to :user, tracks search queries with results count
- **PopularSearch**: tracks search terms with atomic count increments

### External Integrations

- GitHub OAuth via Ueberauth, AWS S3 API, FLAME with Fly.io backend, AppSignal monitoring
- **Tigris Object Storage**: Stores sanitized database dumps for preview app restoration

## Development Guidelines

### Critical Rules

1. **Use Phoenix Generators**: Always use `mix phx.gen.*` for new resources
2. **Context Boundaries**: Use public APIs for cross-context communication
3. **Testing Strategy**: Unit tests for contexts, integration tests for LiveViews, PhoenixTest.Playwright for browser automation with async parallel execution
4. **Flaky Test Prevention**: Use single database fetches, avoid timing windows between assertions and async operations
5. **Real-time Updates**: Subscribe to PubSub in mount/3, handle updates in handle_info/2
6. **Background Jobs**: Use Oban for long-running tasks
7. **CSS Architecture**: Use component-specific class prefixes to avoid collisions
8. **Template Compilation**: ALL `attr` declarations required for Phoenix templates - missing attrs cause silent failures
9. **Dropdown Patterns**: Use JavaScript blur handlers with relatedTarget checks, avoid phx-click-away for complex interactions
10. **Component Attributes**: Maintain alphabetical ordering in both `attr` declarations and HEEx component calls
11. **Route Verification**: Use hybrid approach - `~p` sigil for static routes, string interpolation for dynamic routes
12. **Credo Zero-Tolerance**: All Credo issues must be resolved - no exceptions for production code

### Performance Considerations

- **Database**: Indexes on short_id and user_id, cursor-based pagination, preload associations, GIN indexes for full-text search
- **LiveView**: Temporary assigns for large lists, PubSub for targeted updates, stream-based DOM handling
- **Masonry**: Dynamic batch sizing based on viewport, proper lifecycle management with JavaScript hooks
- **Caching**: Screenshot URLs cached in database, static assets fingerprinted
- **Search**: PostgreSQL websearch_to_tsquery with ts_rank relevance, suggestion loading with 100ms debounce

### Common Pitfalls & Solutions

1. **Screenshot Generation Failures**: Check FLAME backend config and FLY_API_TOKEN
2. **GitHub OAuth Issues**: Ensure GITHUB_REDIRECT_URI matches app settings
3. **CSS Class Collisions**: Use component-specific prefixes (e.g., `drop-full-content` vs generic `drop-body`)
4. **Stream Reset Glitches**: Avoid `stream(:drops, drops, reset: true)` - causes visual artifacts
5. **LiveView Testing**: Components tested through parent LiveViews, not in isolation
6. **Safari Animations**: Requires explicit transition properties for transforms
7. **Dropdown Visibility**: Conditional `:if` rendering more reliable than CSS `hidden` class for testing
8. **Interactive Elements**: Add `tabindex="0"` to clickable divs for proper blur event handling
9. **Flaky Test Race Conditions**: Multiple database queries in same test create timing windows - use single `Repo.get_by!` instead of `List.last(Drops.list_drops())`
10. **Test Async Operations**: Avoid mixing assertions with broadcasts/updates in same test - separate concerns or use consistent data fetching
11. **Phoenix Component Attribute Mismatches**: Missing `attr` declarations cause silent template failures - ensure all HEEx parameters have corresponding `attr` definitions
12. **Route Verification Failures**: Mix of `~p` sigil and string routes cause compilation errors - use hybrid approach based on route type (static vs dynamic)
13. **Code Coverage Exclusions**: Test support files can skew coverage metrics - exclude helper modules from coverage calculations
14. **Credo Variable Shadowing**: Reusing variable names in nested scopes can cause confusion - use descriptive unique names
15. **Systematic Refactoring Dependencies**: UI terminology changes require ordered approach - function names first (affects template calls), UI text second, unit tests last for verification
16. **Test Scope Boundaries**: Feature/browser tests should be excluded from terminology refactoring - only update unit/LiveView tests to maintain consistent CI pipeline
17. **Browser Test Database Integration**: LiveView hooks need explicit sandbox allowance via User-Agent metadata for async feature testing
18. **Async Feature Test Performance**: Parallel browser test execution provides 4.5x speed improvement (93.5s vs 7+ minutes) when properly configured
19. **PhoenixTest.Playwright Helper Methods**: Avoid custom helper methods that return nil/unwrapped values - use native PhoenixTest functionality for reliability
20. **Phoenix File Extension Limitations**: Phoenix doesn't support dynamic route patterns with file extensions (e.g., `/d/:id.md`) - use plug interceptors with binary pattern matching instead
21. **ETS Cache Race Conditions**: ETS table creation in concurrent processes needs proper error handling - use try/rescue blocks to handle ArgumentError on table creation
22. **Markdown Content Caching**: Cache-first patterns (check cache before database) provide significant performance gains for content-heavy endpoints
23. **Binary Pattern Matching for Routes**: Use specific size constraints (e.g., `<<short_id::binary-size(8), ".md">>`) for reliable route interception
24. **Phoenix Pipeline Architecture**: Create dedicated pipelines for different content types (e.g., `:markdown` pipeline without auth/session overhead)

## Key Feature Learnings

### Masonry Layout System

- **Architecture**: CSS Grid structure + Masonry.js positioning + imagesLoaded for detection
- **Batch Sizing**: Mobile 6-12, Tablet 10-20, Desktop 15-40 items based on columns
- **Critical Insights**:
  - Must wait for layout completion before infinite scroll
  - Stream resets cause visual glitches - use page reset instead
  - Different behavior per page: homepage shows "New Drops" button, user page auto-refreshes
  - Simple solutions often beat over-engineered ones (e.g., use broadcast data directly)

### CSS Class Collision Fix

- **Problem**: `.drop-body` class from masonry affected show page content
- **Solution**: Renamed to `.drop-full-content` to avoid collision
- **Lesson**: Component CSS needs proper namespacing to prevent global conflicts

### Implementation Battle Scars

1. **"New Drops" Button**: Simple positioning (`fixed top-20`) beats complex transforms
2. **Loading States**: Required both server (`@loading_more`) and client (`data-end-of-timeline`) coordination
3. **Safari Hover**: Needed vendor prefixes and explicit transition properties
4. **Security Model**: Page-level query filters provide sufficient boundary without redundant checks
5. **Test Failures**: Often reveal deeper architectural inconsistencies

### Sanitized Database System

- **Architecture**: Automated preview app data restoration using sanitized production dumps
- **Scripts**:
  - `priv/repo/sanitize_prod_data.exs`: Anonymizes user data while preserving relationships
  - `priv/repo/restore_sanitized_dump.sh`: Optimized multi-phase restoration for preview apps
- **Integration**: ElixirDrops.Release.migrate/0 automatically detects empty databases and restores dumps
- **Critical Insights**:
  - Database restoration requires PostgreSQL client + AWS CLI in Docker containers
  - Phased restoration (schema → data → indexes) performs better than single operation
  - Safety checks prevent production environment sanitization
  - Stream processing handles large datasets efficiently
  - User tokens must be deleted for security, drops preserved for realistic testing
  - GitHub workflows need DATABASE_DUMP_FILE variable for preview apps

### Search System Architecture

- **Full-Text Search**: PostgreSQL tsvector with GIN indexes, websearch_to_tsquery parsing, ts_rank relevance scoring
- **Search Context**: Dedicated context with SearchHistory and PopularSearch schemas for user behavior tracking
- **Suggestions Algorithm**: 2+3 rule (2 recent history + 3 popular for authenticated, 5 popular for anonymous users)
- **Mobile/Desktop UX**: Responsive design with full-screen mobile overlay using Phoenix.JS, desktop dropdown with keyboard navigation
- **Dev Authentication**: Token-based bypass system using standard session flow (`/dev/auth/:user_id` route)
- **Template Compilation Patterns**: ALL `attr` declarations mandatory - missing attrs cause silent template failures
- **Dropdown Implementation**: JavaScript blur handlers with relatedTarget validation, avoid phx-click-away for complex interactions
- **Interactive Elements**: `tabindex="0"` required for proper blur event handling on clickable divs
- **Testing Methodology**: Manual testing for 3+ seconds to verify dropdown persistence, DOM element checks over CSS class inspection

### Markdown Export System

- **Architecture**: Clean separation between formatter (content generation), cache (performance), controller (HTTP handling), and interceptor (routing)
- **Phoenix Route Limitations**: Phoenix doesn't support file extensions in dynamic routes - solved with binary pattern matching plug interceptor
- **Performance Optimization**: Cache-first patterns provide major performance gains - check ETS cache before hitting database
- **Content Formatting**: IO lists for efficient string building, proper markdown structure with metadata for LLM consumption
- **Cache Strategy**: ETS in-memory storage with 5-minute TTL matching HTTP cache headers, composite keys for cache invalidation
- **Error Handling**: Graceful degradation - missing drops return 404 with markdown content, cache failures fall back to database
- **UI Integration**: Figma-compliant dropdown menus with proper spacing, typography, and interaction patterns

### Testing Patterns

- **Race Condition Prevention**: Use `Repo.get_by!` with specific filters instead of `List.last(Drops.list_drops())` to ensure consistent data fetching
- **Async Operation Testing**: Separate test phases - assert initial state, then test updates/broadcasts separately to avoid timing windows
- **Flaky Test Debugging**: Use `mix test --repeat-until-failure 10000` to reproduce intermittent failures, look for multiple DB queries and shared state
- **LiveView + Oban Integration**: Test initial state assertion, then proceed with background job triggers separately to prevent race conditions
- **PhoenixTest.Playwright Patterns**: `conn` parameter is browser session, not Plug.Conn; use domain-based test organization over technology separation
- **Browser Automation**: Real Chrome execution enables JavaScript testing, form interactions, and responsive viewport testing
- **Route Testing Strategy**: Static routes (`~p"/profile"`), dynamic routes (`"/d/#{drop.short_id}"`), error testing (`"/invalid/route"`)
- **Coverage Quality Gates**: 97%+ coverage requirement with proper exclusions for test support files
- **Systematic Refactoring Testing**: For UI terminology changes - update unit/LiveView tests only, exclude feature/browser tests from scope to maintain CI consistency
- **Element Selector Updates**: When updating component function names or IDs, ensure corresponding test selectors are updated in tandem
- **Async Feature Test Configuration**: Enable `async: true` in FeatureCase with LiveAcceptance hook for 4.5x speed improvement, requires User-Agent metadata for database sandbox
- **Browser Test Debugging Strategy**: Fix technical issues first (environment, helper methods), then align test expectations with actual UI implementation
- **LiveView Database Sandbox**: Use `Phoenix.Ecto.SQL.Sandbox` plug + `LiveAcceptance` hook with User-Agent encoding for proper database ownership in async browser tests

### Development Workflow

- **Planning**: Use `codegen/plans/` directory for feature plans
- **Rules**: Centralized via `@./codegen/rules/INDEX.md` - Phoenix patterns, Elixir standards, testing practices
- **Commands**: `mix setup`, `mix phx.server`, `mix test`, `mix format`, `mix prettier`
- **Deployment**: Docker-based with matching Chrome/ChromeDriver for Wallaby tests
