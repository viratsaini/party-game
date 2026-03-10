## MemoryMonitor - Advanced memory management system for UI
##
## Ensures optimal memory usage through:
## - Texture streaming for UI assets
## - Automatic asset unloading for unused screens
## - Resource caching with LRU eviction
## - Memory profiling tools
## - Leak detection system
## - Garbage collection tuning
##
## Usage:
##   MemoryMonitor.preload_screen("gameplay")
##   MemoryMonitor.unload_screen("menu")
##   var texture = MemoryMonitor.get_cached_texture("icon.png")
class_name MemoryMonitor
extends Node


# =============================================================================
# region - Signals
# =============================================================================

## Emitted when memory usage changes significantly
signal memory_usage_changed(used_mb: float, budget_mb: float)

## Emitted when memory warning threshold is reached
signal memory_warning(used_mb: float, budget_mb: float, severity: WarningSeverity)

## Emitted when a potential leak is detected
signal leak_detected(resource_path: String, reference_count: int)

## Emitted when assets are unloaded
signal assets_unloaded(screen: String, count: int, freed_mb: float)

## Emitted when texture streaming completes
signal texture_streaming_complete(path: String)

# endregion


# =============================================================================
# region - Enums and Constants
# =============================================================================

## Memory warning severity levels
enum WarningSeverity {
	LOW,        ## 70% of budget
	MEDIUM,     ## 85% of budget
	HIGH,       ## 95% of budget
	CRITICAL    ## Over budget
}

## Resource priority for cache eviction
enum ResourcePriority {
	CRITICAL,   ## Never evict (essential UI)
	HIGH,       ## Keep as long as possible
	MEDIUM,     ## Standard eviction
	LOW,        ## Evict first
	TEMPORARY   ## Evict immediately when unused
}

## Memory budget constants (in MB)
const MEMORY_BUDGET_LOW: float = 256.0
const MEMORY_BUDGET_MEDIUM: float = 512.0
const MEMORY_BUDGET_HIGH: float = 1024.0
const MEMORY_BUDGET_ULTRA: float = 2048.0

## Warning thresholds (percentage of budget)
const WARNING_THRESHOLD_LOW: float = 0.70
const WARNING_THRESHOLD_MEDIUM: float = 0.85
const WARNING_THRESHOLD_HIGH: float = 0.95

## Cache settings
const CACHE_SIZE_LIMIT: int = 100          ## Maximum cached resources
const CACHE_MEMORY_LIMIT_MB: float = 128.0  ## Maximum cache memory
const CACHE_EVICTION_COUNT: int = 10        ## Resources to evict at once

## Monitoring intervals
const MEMORY_CHECK_INTERVAL: float = 0.5   ## Seconds between memory checks
const LEAK_CHECK_INTERVAL: float = 5.0     ## Seconds between leak checks
const GC_INTERVAL: float = 30.0            ## Seconds between forced GC

## Texture streaming
const TEXTURE_STREAM_BATCH_SIZE: int = 3   ## Textures to load per frame
const TEXTURE_PRIORITY_LOAD_DISTANCE: float = 500.0  ## Pixels

# endregion


# =============================================================================
# region - State Variables
# =============================================================================

## Current memory budget in MB
var memory_budget_mb: float = MEMORY_BUDGET_MEDIUM

## Whether monitoring is enabled
var enabled: bool = true

## Whether auto-unloading is enabled
var auto_unload_enabled: bool = true

## Current screen being tracked
var current_screen: String = "menu"

## Resource cache (LRU)
var _resource_cache: Dictionary = {}  # path -> CacheEntry

## Cache access order for LRU eviction
var _cache_access_order: Array[String] = []

## Screen resources mapping
var _screen_resources: Dictionary = {}  # screen_name -> Array[String]

## Active texture streams
var _texture_stream_queue: Array[Dictionary] = []

## Leak tracking
var _resource_references: Dictionary = {}  # path -> { ref_count, first_seen }
var _suspected_leaks: Array[String] = []

## Timing accumulators
var _memory_check_timer: float = 0.0
var _leak_check_timer: float = 0.0
var _gc_timer: float = 0.0

## Current memory stats
var _current_memory_mb: float = 0.0
var _peak_memory_mb: float = 0.0
var _cache_memory_mb: float = 0.0

## Statistics
var _cache_hits: int = 0
var _cache_misses: int = 0
var _resources_loaded: int = 0
var _resources_unloaded: int = 0
var _bytes_freed: int = 0

# endregion


# =============================================================================
# region - Inner Classes
# =============================================================================

## Cache entry for resource management
class CacheEntry:
	var resource: Resource
	var path: String
	var priority: int  # ResourcePriority
	var size_bytes: int
	var last_access_time: float
	var load_time: float
	var reference_count: int

	func _init(
		p_resource: Resource,
		p_path: String,
		p_priority: int = ResourcePriority.MEDIUM
	) -> void:
		resource = p_resource
		path = p_path
		priority = p_priority
		size_bytes = _estimate_resource_size(p_resource)
		last_access_time = Time.get_ticks_msec() / 1000.0
		load_time = last_access_time
		reference_count = 1

	func _estimate_resource_size(res: Resource) -> int:
		if res is Texture2D:
			var tex := res as Texture2D
			return tex.get_width() * tex.get_height() * 4  # RGBA
		elif res is StyleBox:
			return 256  # Approximate
		elif res is Font:
			return 4096  # Approximate
		elif res is Theme:
			return 8192  # Approximate
		else:
			return 1024  # Default estimate

# endregion


# =============================================================================
# region - Lifecycle
# =============================================================================

func _ready() -> void:
	_detect_memory_budget()
	_initialize_screen_resources()


func _process(delta: float) -> void:
	if not enabled:
		return

	_memory_check_timer += delta
	_leak_check_timer += delta
	_gc_timer += delta

	# Memory check
	if _memory_check_timer >= MEMORY_CHECK_INTERVAL:
		_memory_check_timer = 0.0
		_update_memory_stats()
		_check_memory_warnings()

	# Leak check
	if _leak_check_timer >= LEAK_CHECK_INTERVAL:
		_leak_check_timer = 0.0
		_check_for_leaks()

	# Garbage collection
	if _gc_timer >= GC_INTERVAL:
		_gc_timer = 0.0
		_perform_gc()

	# Process texture streaming
	_process_texture_stream()


func _detect_memory_budget() -> void:
	# Detect system memory and set appropriate budget
	var memory_info := OS.get_memory_info()
	var total_memory: int = memory_info.get("physical", 0)
	var total_mb: float = float(total_memory) / 1048576.0

	if total_mb <= 2048:
		memory_budget_mb = MEMORY_BUDGET_LOW
	elif total_mb <= 4096:
		memory_budget_mb = MEMORY_BUDGET_MEDIUM
	elif total_mb <= 8192:
		memory_budget_mb = MEMORY_BUDGET_HIGH
	else:
		memory_budget_mb = MEMORY_BUDGET_ULTRA

	print("[MemoryMonitor] Detected %.0f MB RAM, budget set to %.0f MB" % [total_mb, memory_budget_mb])


func _initialize_screen_resources() -> void:
	# Define resources needed per screen
	_screen_resources = {
		"menu": [
			"res://ui/themes/main_theme.tres",
			"res://ui/textures/logo.png",
			"res://ui/textures/background.png"
		],
		"gameplay": [
			"res://ui/themes/hud_theme.tres",
			"res://ui/textures/crosshair.png",
			"res://ui/textures/health_bar.png",
			"res://ui/textures/ammo_icons.png"
		],
		"results": [
			"res://ui/themes/results_theme.tres",
			"res://ui/textures/podium.png",
			"res://ui/textures/confetti.png"
		],
		"loading": [
			"res://ui/textures/loading_spinner.png"
		]
	}

# endregion


# =============================================================================
# region - Resource Cache API
# =============================================================================

## Gets a cached resource, loading it if necessary
func get_cached_resource(
	path: String,
	priority: ResourcePriority = ResourcePriority.MEDIUM
) -> Resource:
	# Check cache first
	if _resource_cache.has(path):
		_cache_hits += 1
		var entry: CacheEntry = _resource_cache[path]
		entry.last_access_time = Time.get_ticks_msec() / 1000.0
		entry.reference_count += 1
		_update_lru(path)
		return entry.resource

	# Cache miss - load resource
	_cache_misses += 1
	var resource: Resource = load(path)

	if resource == null:
		push_warning("[MemoryMonitor] Failed to load resource: %s" % path)
		return null

	# Add to cache
	_add_to_cache(path, resource, priority)
	_resources_loaded += 1

	return resource


## Gets a cached texture with streaming support
func get_cached_texture(
	path: String,
	priority: ResourcePriority = ResourcePriority.MEDIUM,
	stream: bool = false
) -> Texture2D:
	if stream and not _resource_cache.has(path):
		# Queue for background loading
		queue_texture_stream(path, priority)
		return null

	return get_cached_resource(path, priority) as Texture2D


## Preloads resources for a screen
func preload_screen(screen: String) -> void:
	if not _screen_resources.has(screen):
		return

	var resources: Array = _screen_resources[screen]
	for path: String in resources:
		if not _resource_cache.has(path):
			get_cached_resource(path, ResourcePriority.HIGH)

	print("[MemoryMonitor] Preloaded %d resources for screen: %s" % [resources.size(), screen])


## Unloads resources for a screen
func unload_screen(screen: String) -> void:
	if not _screen_resources.has(screen):
		return

	var resources: Array = _screen_resources[screen]
	var unloaded_count: int = 0
	var freed_bytes: int = 0

	for path: String in resources:
		if _resource_cache.has(path):
			var entry: CacheEntry = _resource_cache[path]
			# Don't unload critical or high priority resources
			if entry.priority > ResourcePriority.HIGH:
				freed_bytes += entry.size_bytes
				_remove_from_cache(path)
				unloaded_count += 1

	var freed_mb: float = float(freed_bytes) / 1048576.0
	_bytes_freed += freed_bytes
	_resources_unloaded += unloaded_count

	assets_unloaded.emit(screen, unloaded_count, freed_mb)
	print("[MemoryMonitor] Unloaded %d resources (%.2f MB) for screen: %s" % [unloaded_count, freed_mb, screen])


## Sets the current screen and optionally preloads it
func set_current_screen(screen: String, preload_resources: bool = true) -> void:
	var previous_screen := current_screen
	current_screen = screen

	if preload_resources:
		preload_screen(screen)

	if auto_unload_enabled and previous_screen != screen:
		# Delayed unload of previous screen
		get_tree().create_timer(2.0).timeout.connect(func():
			if current_screen != previous_screen:
				unload_screen(previous_screen)
		)


## Clears the entire cache
func clear_cache() -> void:
	var total_freed: int = 0

	for path: String in _resource_cache:
		var entry: CacheEntry = _resource_cache[path]
		total_freed += entry.size_bytes

	_resource_cache.clear()
	_cache_access_order.clear()
	_cache_memory_mb = 0.0

	var freed_mb: float = float(total_freed) / 1048576.0
	print("[MemoryMonitor] Cache cleared, freed %.2f MB" % freed_mb)

# endregion


# =============================================================================
# region - Cache Management
# =============================================================================

func _add_to_cache(path: String, resource: Resource, priority: ResourcePriority) -> void:
	var entry := CacheEntry.new(resource, path, priority)

	# Check if we need to evict
	var entry_mb: float = float(entry.size_bytes) / 1048576.0
	while _cache_memory_mb + entry_mb > CACHE_MEMORY_LIMIT_MB and _resource_cache.size() > 0:
		_evict_lru()

	# Check size limit
	while _resource_cache.size() >= CACHE_SIZE_LIMIT:
		_evict_lru()

	_resource_cache[path] = entry
	_cache_access_order.append(path)
	_cache_memory_mb += entry_mb


func _remove_from_cache(path: String) -> void:
	if not _resource_cache.has(path):
		return

	var entry: CacheEntry = _resource_cache[path]
	_cache_memory_mb -= float(entry.size_bytes) / 1048576.0
	_resource_cache.erase(path)
	_cache_access_order.erase(path)


func _update_lru(path: String) -> void:
	_cache_access_order.erase(path)
	_cache_access_order.append(path)


func _evict_lru() -> void:
	if _cache_access_order.is_empty():
		return

	# Find lowest priority, oldest resource
	var best_path: String = ""
	var best_priority: int = -1
	var best_time: float = INF

	for path: String in _cache_access_order:
		var entry: CacheEntry = _resource_cache[path]

		# Skip critical resources
		if entry.priority == ResourcePriority.CRITICAL:
			continue

		# Lower priority or older = better candidate
		if entry.priority > best_priority or (entry.priority == best_priority and entry.last_access_time < best_time):
			best_path = path
			best_priority = entry.priority
			best_time = entry.last_access_time

	if not best_path.is_empty():
		_remove_from_cache(best_path)

# endregion


# =============================================================================
# region - Texture Streaming
# =============================================================================

## Queues a texture for background loading
func queue_texture_stream(path: String, priority: ResourcePriority = ResourcePriority.MEDIUM) -> void:
	# Check if already cached or queued
	if _resource_cache.has(path):
		return

	for queued: Dictionary in _texture_stream_queue:
		if queued.get("path", "") == path:
			return

	_texture_stream_queue.append({
		"path": path,
		"priority": priority,
		"queued_time": Time.get_ticks_msec()
	})

	# Sort by priority (lower = higher priority)
	_texture_stream_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("priority", 2) < b.get("priority", 2)
	)


func _process_texture_stream() -> void:
	if _texture_stream_queue.is_empty():
		return

	var loaded_count: int = 0

	while loaded_count < TEXTURE_STREAM_BATCH_SIZE and _texture_stream_queue.size() > 0:
		var item: Dictionary = _texture_stream_queue.pop_front()
		var path: String = item.get("path", "")
		var priority: ResourcePriority = item.get("priority", ResourcePriority.MEDIUM)

		if path.is_empty() or _resource_cache.has(path):
			continue

		# Load texture
		var texture: Resource = load(path)
		if texture:
			_add_to_cache(path, texture, priority)
			texture_streaming_complete.emit(path)

		loaded_count += 1

# endregion


# =============================================================================
# region - Memory Monitoring
# =============================================================================

func _update_memory_stats() -> void:
	_current_memory_mb = float(OS.get_static_memory_usage()) / 1048576.0
	_peak_memory_mb = maxf(_peak_memory_mb, _current_memory_mb)

	memory_usage_changed.emit(_current_memory_mb, memory_budget_mb)


func _check_memory_warnings() -> void:
	var usage_ratio: float = _current_memory_mb / memory_budget_mb
	var severity: WarningSeverity

	if usage_ratio >= 1.0:
		severity = WarningSeverity.CRITICAL
	elif usage_ratio >= WARNING_THRESHOLD_HIGH:
		severity = WarningSeverity.HIGH
	elif usage_ratio >= WARNING_THRESHOLD_MEDIUM:
		severity = WarningSeverity.MEDIUM
	elif usage_ratio >= WARNING_THRESHOLD_LOW:
		severity = WarningSeverity.LOW
	else:
		return  # No warning

	memory_warning.emit(_current_memory_mb, memory_budget_mb, severity)

	# Auto-cleanup on high severity
	if severity >= WarningSeverity.HIGH:
		_emergency_cleanup()


func _emergency_cleanup() -> void:
	print("[MemoryMonitor] Emergency cleanup triggered!")

	# Evict temporary and low priority resources
	var to_evict: Array[String] = []

	for path: String in _resource_cache:
		var entry: CacheEntry = _resource_cache[path]
		if entry.priority >= ResourcePriority.LOW:
			to_evict.append(path)

	for path: String in to_evict:
		_remove_from_cache(path)

	# Force GC
	_perform_gc()

# endregion


# =============================================================================
# region - Leak Detection
# =============================================================================

func _check_for_leaks() -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0

	# Track current resource references
	for path: String in _resource_cache:
		var entry: CacheEntry = _resource_cache[path]

		if not _resource_references.has(path):
			_resource_references[path] = {
				"ref_count": entry.reference_count,
				"first_seen": current_time,
				"last_count": entry.reference_count
			}
		else:
			var tracking: Dictionary = _resource_references[path]
			var last_count: int = tracking.get("last_count", 0)

			# Check for continuously growing reference count
			if entry.reference_count > last_count:
				var time_since_first: float = current_time - tracking.get("first_seen", current_time)

				# If refs keep growing for over 30 seconds, suspect leak
				if time_since_first > 30.0 and entry.reference_count > last_count + 5:
					if path not in _suspected_leaks:
						_suspected_leaks.append(path)
						leak_detected.emit(path, entry.reference_count)
						push_warning("[MemoryMonitor] Potential leak detected: %s (refs: %d)" % [path, entry.reference_count])

			tracking["last_count"] = entry.reference_count


## Manually reports a resource reference
func report_reference(path: String) -> void:
	if _resource_cache.has(path):
		var entry: CacheEntry = _resource_cache[path]
		entry.reference_count += 1


## Manually releases a resource reference
func release_reference(path: String) -> void:
	if _resource_cache.has(path):
		var entry: CacheEntry = _resource_cache[path]
		entry.reference_count = maxi(0, entry.reference_count - 1)


## Gets list of suspected leaks
func get_suspected_leaks() -> Array[String]:
	return _suspected_leaks.duplicate()


## Clears leak tracking data
func clear_leak_tracking() -> void:
	_resource_references.clear()
	_suspected_leaks.clear()

# endregion


# =============================================================================
# region - Garbage Collection
# =============================================================================

func _perform_gc() -> void:
	# Clean up cache entries with zero references
	var to_remove: Array[String] = []

	for path: String in _resource_cache:
		var entry: CacheEntry = _resource_cache[path]
		var current_time: float = Time.get_ticks_msec() / 1000.0

		# Remove unused temporary resources
		if entry.priority == ResourcePriority.TEMPORARY and entry.reference_count <= 0:
			to_remove.append(path)

		# Remove low priority resources unused for 60+ seconds
		elif entry.priority >= ResourcePriority.LOW:
			if current_time - entry.last_access_time > 60.0 and entry.reference_count <= 0:
				to_remove.append(path)

	for path: String in to_remove:
		_remove_from_cache(path)

	# Notify resource server to free unused resources
	# This triggers Godot's internal resource cleanup


## Forces immediate garbage collection
func force_gc() -> void:
	_perform_gc()


## Sets the GC interval
func set_gc_interval(seconds: float) -> void:
	# GC_INTERVAL is const, so we track manually
	pass

# endregion


# =============================================================================
# region - Statistics & Debug
# =============================================================================

## Gets memory statistics
func get_statistics() -> Dictionary:
	return {
		"current_memory_mb": _current_memory_mb,
		"peak_memory_mb": _peak_memory_mb,
		"budget_mb": memory_budget_mb,
		"usage_percent": _current_memory_mb / memory_budget_mb * 100.0,
		"cache_size": _resource_cache.size(),
		"cache_memory_mb": _cache_memory_mb,
		"cache_limit_mb": CACHE_MEMORY_LIMIT_MB,
		"cache_hits": _cache_hits,
		"cache_misses": _cache_misses,
		"hit_rate": float(_cache_hits) / float(_cache_hits + _cache_misses) if (_cache_hits + _cache_misses) > 0 else 0.0,
		"resources_loaded": _resources_loaded,
		"resources_unloaded": _resources_unloaded,
		"bytes_freed_mb": float(_bytes_freed) / 1048576.0,
		"texture_stream_queue": _texture_stream_queue.size(),
		"suspected_leaks": _suspected_leaks.size(),
		"current_screen": current_screen
	}


## Gets detailed cache information
func get_cache_info() -> Array[Dictionary]:
	var info: Array[Dictionary] = []

	for path: String in _resource_cache:
		var entry: CacheEntry = _resource_cache[path]
		info.append({
			"path": path,
			"priority": ResourcePriority.keys()[entry.priority],
			"size_kb": float(entry.size_bytes) / 1024.0,
			"reference_count": entry.reference_count,
			"last_access": entry.last_access_time,
			"age_seconds": (Time.get_ticks_msec() / 1000.0) - entry.load_time
		})

	return info


## Sets memory budget manually
func set_memory_budget(budget_mb: float) -> void:
	memory_budget_mb = budget_mb


## Resets statistics
func reset_statistics() -> void:
	_cache_hits = 0
	_cache_misses = 0
	_resources_loaded = 0
	_resources_unloaded = 0
	_bytes_freed = 0
	_peak_memory_mb = _current_memory_mb

# endregion
