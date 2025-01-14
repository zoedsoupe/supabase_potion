# Changelog

All notable changes to this project are documented in this file.

## [0.6.0] - 2025-01-10
### Added
- Enhanced HTTP handling with support for custom headers, streaming, and centralized error management.
- Improved test coverage and added dependency `mox` for mocking.
- CI/CD pipeline improvements with caching for faster builds.

### Fixed
- Resolved header merging issues and inconsistencies in JSON error handling.

### Removed
- Dropped `manage_clients` option; explicit OTP management required.

### Issues
- Fixed "[Fetcher] Extract error parsing to its own module" [#23](https://github.com/supabase-community/supabase-ex/issues/23)
- Fixed "Unable to pass `auth` key inside options to `init_client`" [#45](https://github.com/supabase-community/supabase-ex/issues/45)
- Fixed "Proposal to refactor and simplify the `Supabase.Fetcher` module" [#51](https://github.com/supabase-community/supabase-ex/issues/51)
- Fixed "Invalid Unicode error during file uploads (affets `storage-ex`)" [#52](https://github.com/supabase-community/supabase-ex/issues/52)

---

## [0.5.1] - 2024-09-21
### Added
- Improved error handling for HTTP fetch operations.
- Added optional retry policies for idempotent requests.

### Fixed
- Resolved race conditions in streaming functionality.

---

## [0.5.0] - 2024-09-21
### Added
- Support for direct file uploads to cloud storage.
- Enhanced real-time subscription management.

### Fixed
- Corrected WebSocket reconnection logic under high load.

---

## [0.4.1] - 2024-08-30
### Changed
- Performance optimizations in JSON encoding and decoding.
- Improved logging for debugging.

### Fixed
- Addressed memory leaks in connection pooling.

---

## [0.4.0] - 2024-08-30
### Added
- Introduced WebSocket monitoring tools.
- Support for encrypted token storage.

---

## [0.3.7] - 2024-05-14
### Added
- Initial implementation of streaming API for large datasets.

### Fixed
- Bug fixes in the pagination logic.

---

## [0.3.6] - 2024-04-28
### Added
- Experimental support for Ecto integration.

---

## [0.3.5] - 2024-04-21
### Fixed
- Addressed intermittent crashes when initializing connections.

---

## [0.3.4] - 2024-04-21
### Changed
- Optimized internal handling of database transactions.

---

## [0.3.3] - 2024-04-21
### Added
- Support for preflight HTTP requests.

---

## [0.3.2] - 2024-04-16
### Fixed
- Resolved issues with JSON payload validation.

---

## [0.3.1] - 2024-04-15
### Fixed
- Resolved inconsistent query results in edge cases.

---

## [0.3.0] - 2023-11-20
### Added
- Major refactor introducing modular architecture.
- Support for real-time database change notifications.

---

## [0.2.3] - 2023-10-11
### Fixed
- Patched security vulnerabilities in session handling.

---

## [0.2.2] - 2023-10-10
### Added
- Middleware support for request customization.

---

## [0.2.1] - 2023-10-10
### Fixed
- Corrected behavior for long-lived connections.

---

## [0.2.0] - 2023-10-05
### Added
- Initial implementation of role-based access control.

---

## [0.1.0] - 2023-09-18
### Added
- Initial release with core features: database access, authentication, and storage support.
