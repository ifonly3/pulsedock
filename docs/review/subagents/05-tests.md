# Tests 测试质量审查报告

## 审查概要

- 文件：`Tests/SharedMetricsTests/MetricFormattingTests.swift`
- 总行数：7702（任务描述为 7401，实际为 7702，文件仍在增长）
- 测试函数数：**234** 个 `@Test`
- `#expect` 断言总数：**2623**
- 断言类型分布：
  - `.contains(...)` 源码/文档扫描：**2129**（约占 81%）
  - `==` 行为等值断言：**439**（约占 17%）
  - `audit.contains(...)`（校验 `docs/data-capability-audit.md` 文本）：**367**
  - `JSONDecoder().decode` 遗留数据解码行为：**33**
  - `.range(of:)` 区间提取/顺序断言：**75**
- 测试类型分布（按函数估算）：
  - 纯行为单元测试：**约 15**（~6%）
  - 行为 + 源码扫描混合：**约 35**（~15%）
  - 纯源码字符串扫描：**约 184**（~79%）
- 测试框架：Swift Testing（`@Test` / `#expect` / `#require`），现代且合适
- 引用的被测源文件：`MetricSnapshot.swift`、`SystemSampler.swift`、`MetricFormatting.swift`、`MetricsStore.swift`、`DashboardView.swift`、`WidgetPanelView.swift`、`AppDelegate.swift`、`SystemDashboardWidget.swift`、`MenuBarPopoverGeometry.swift`、`WidgetTimelineKind.swift`，以及 `scripts/*.sh`、`scripts/*.rb`、`Resources/*.plist`、`README.md`、`LICENSE`、`docs/*.md`、`*.pbxproj`

## 测试覆盖范围分析

234 个测试函数按功能域归纳如下：

### 1. 格式化器（真实行为单元测试，覆盖率低）
- `percentageFormatterClampsAndRoundsValues` (7)
- `bytesFormatterUsesBinaryUnits` (13)
- `networkRateFormatterUsesBitsPerSecond` (19)
- `minutesFormatterUsesCompactDurations` (614)
- `displaySnapshotExposesExpectedStrings` (620)
- `formattersGuardNonFiniteDoubleInputsBeforeIntegerConversion` (7220，仅源码扫描)

### 2. 网络路径与能力（大量源码扫描 + 少量行为）
- `networkPathStatusUsesUserReadableLabels` (48)
- `unknownNetworkPathDoesNotBorrowOnlineDetailsOrProgress` (93)
- `sampleTimeUsesReportedStateInsteadOfPlaceholderTimestampAcrossSurfaces` (147)
- `networkPathSurfacesPublicPathCapabilities` (246)
- `networkPathSupportFalseUsesUnsupportedInsteadOfNotReportedWhenPathIsReported` (290)
- `legacyNetworkPathMissingSupportFlagsDoesNotInventUnsupportedCapabilities` (345)
- `initializerNetworkPathStatusOnlyDoesNotInventSupportOrCostReports` (387)
- `networkPathSupportRowsUseUnavailableWhenPathIsOffline` (429)
- `networkPageSurfacesLowDataAndMeteredPathFlags` (467)
- `legacyNetworkPathMissingCostFlagsDoesNotInventDisabledPathFlags` (524)
- `networkPageSurfacesAggregateThroughputTrend` (572)
- `networkPageTrendPanelSurfacesPathStatusHistory` (592)
- `networkPathTrendFiltersUnknownSamplesWithoutDroppingOfflineStates` (1584)
- `networkRuleTablesUseReportedStateInsteadOfWarningWhenPathIsMissing` (1605)

### 3. 网络：接口、字节、速率、MTU、链路速率
- `networkSamplerUsesPublic64BitInterfaceCountersWhenAvailable` (26)
- `missingNetworkInterfaceInventoryUsesReportedStateInsteadOfZeroActiveInterfaces` (1442)
- `networkInterfaceTableFiltersUnreportedRowsAndShowsEmptyState` (1505)
- `networkPageSummarySurfacesSampledInterfaceCount` (1562)
- `networkUIOnlyNamesImplementedSignals` (5895)
- `networkMetricCardsDoNotShowBaselineProgressAsPercent` (5908)
- `networkInterfaceSnapshotsAvoidLocalAddresses` (5937)
- `networkInterfaceSnapshotsAvoidRawInterfaceNames` (5961)
- `networkInterfaceDescriptorsUseShortCacheWhileCountersStayLive` (6049)
- `networkInterfacePageSurfacesPublicMTUWithoutRawNames` (6071)
- `missingNetworkMTUUsesReportedStateInsteadOfZero` (6104)
- `networkInterfaceStateTextUsesSharedModelLabels` (6162)
- `initializerNetworkInterfaceCountersOnlyDoesNotInventOnlineOrOfflineState` (6221)
- `legacyNetworkInterfaceMissingStateFieldsDoesNotInventOfflineState` (6265)
- `activeInterfaceProgressIgnoresLegacyInterfacesWithoutStateReports` (6306)
- `missingNetworkLinkSpeedUsesReportedStateInsteadOfZeroRate` (6333)
- `networkInterfacePageSurfacesPublicPacketAndErrorCountersWithoutRawNames` (6388)
- `missingNetworkPacketCountersUseReportedStateInsteadOfZeroCounts` (6426)
- `missingNetworkByteCountersUseReportedStateInsteadOfZeroBytes` (6486)
- `missingNetworkRateUsesReportedStateInsteadOfZeroRateAcrossSurfaces` (6539)
- `aggregateNetworkDirectionsRequireDirectionFieldsInsteadOfBorrowingTotalCounterState` (7232)
- `interfaceByteCountTextRequiresActualReceivedAndSentFields` (7258)

### 4. 负载 / CPU 核心与品牌
- `missingLoadAveragesUseReportedStateInsteadOfZeroLoadAcrossSurfaces` (650)
- `loadProgressRequiresReportedActiveProcessorCount` (711)
- `missingCPUBrandUsesReportedStateInsteadOfGenericMacLabel` (758)
- `cpuPageSurfacesPublicActiveProcessorCount` (2042)
- `processorCountTextUsesReportedStateInsteadOfZeroCoreLabels` (2077)
- `legacySnapshotsDoNotInventProcessorCountsDuringDecode` (2130)
- `cpuSamplerDoesNotReportSyntheticZeroCoreUsagesWhilePriming` (2173)
- `missingCPUUsageUsesReportedStateInsteadOfZeroPercentAcrossSurfaces` (1243)
- `initializerCPUValueDoesNotReportUsageWithoutExplicitSampleState` (1283)
- `cpuTrendChartsFilterMissingUsageSamplesInsteadOfPlottingZeroDips` (1314)

### 5. 存储 / 磁盘
- `missingPrimaryDiskCapacityUsesReportedStateInsteadOfZeroBytes` (781)
- `missingStorageVolumeCapacityUsesReportedStateInsteadOfZeroBytes` (835)
- `missingStorageInventoryUsesReportedStateInsteadOfZeroVolumeCountsAcrossSurfaces` (901)
- `legacyStorageVolumeRecordWithoutReportedFieldsDoesNotInventVolumeInventory` (980)
- `storageSamplerUsesPublicImportantAvailableCapacityWhenReported` (5369)
- `storageInventoryDoesNotStoreMountPaths` (5411)
- `storageInventoryAvoidsUserDefinedVolumeNames` (5429)
- `storagePageShowsPerVolumeUsedBytesAndUsage` (5459)
- `storagePageUsesSharedVolumeKindAndAccessTextWithoutVolumeNames` (5485)
- `legacyStorageVolumeMissingKindAndAccessDoesNotInventExternalWritableState` (5578)
- `initializerStorageVolumeCapacityOnlyDoesNotInventExternalWritableState` (5628)
- `storageKindReportFalseSuppressesResidualRemovableFlags` (5666)
- `storageFileSystemUsesReportedStateInsteadOfUnknownFallback` (5702)
- `diskThresholdAppliesAcrossOverviewAndStoragePages` (6810)

### 6. 内存
- `missingMemoryCapacityUsesReportedStateInsteadOfZeroBytes` (1016)
- `legacyMemorySnapshotMissingCompositionDoesNotInventZeroByteDetails` (1057)
- `initializerMemoryCapacityOnlyDoesNotInventZeroByteComposition` (1109)
- `memoryUICopyReflectsUsageNotPressure` (6626)
- `memorySamplerExposesSwapUsageFromPublicSysctl` (6638)
- `memorySamplerKeepsUsedCachedAndFreePagesDisjoint` (6679)
- `memorySegmentBarUsesAvailableWidthInsteadOfMagicConstant` (7679)
- `samplerReleasesMachHostPortsAndDoesNotReportFailedMemoryStatsAsZeroUsage` (7320)

### 7. 使用率 / 阈值 / 状态聚合
- `missingUsagePercentagesUseReportedStateInsteadOfZeroPercentAcrossSurfaces` (1148)
- `thresholdSurfacesUseReportedStateInsteadOfNormalWhenUsageIsMissing` (1192)
- `statusSummaryNeutralBadgeUsesNotReportedLabelInsteadOfOptional` (1227)
- `currentProgressSurfacesSuppressMissingSamplesInsteadOfDrawingZeroProgress` (1364)
- `menuPopoverProgressSuppressesMissingSamplesInsteadOfDrawingZeroProgress` (1417)
- `capacityAndNetworkTrendChartsFilterMissingSamplesInsteadOfPlottingZeroDips` (1334)
- `progressBarsDoNotDrawFilledMinimumForTrueZeroValues` (7353)
- `compactInventoryAndUptimeSurfacesUseNeutralTintWhenMissing` (4462)

### 8. 运行中 App / 进程
- `samplerDoesNotExposeCrossProcessDetailsInAppStoreMode` (1640)
- `runningAppsUsePublicWorkspaceStateWithoutResourceScanning` (1647)
- `legacyRunningAppListRecordWithoutReportedFieldsDoesNotInventAppListCounts` (1783)
- `legacyRunningAppListWithoutCountFieldsDoesNotInventZeroCounts` (1820)
- `runningAppPageUsesSharedProcessDisplayText` (1873)
- `legacyRunningAppMissingStateFieldsDoesNotInventRunningState` (1942)
- `initializerRunningAppCapabilityOnlyDoesNotInventRunningState` (1972)
- `runningAppModelDoesNotKeepZeroedResourcePlaceholders` (2000)
- `runningAppUIAvoidsProcessIdentifiers` (2023)
- `partialLegacyRunningAppCountsDoNotInventMissingZeroCounts` (7276)
- `overviewRunningAppSummarySurfacesWorkspaceStateCounts` (6859)

### 9. 硬件库存 / 系统信息 / 内核
- `samplerCollectsPublicHardwareInventory` (2034)
- `samplerProducesCodableWidgetSnapshot` (2190)
- `samplerKeepsPrivateHardwareDetailsDisabled` (2200)
- `unsupportedSensorFieldsAreNotModeledAsPlaceholders` (2211)
- `systemUptimeIsLiveDataWithRequiredReasonDeclarations` (2234)
- `missingUptimeUsesReportedStateInsteadOfZeroDurationAcrossSurfaces` (2274)
- `systemStatusSurfacesPublicDarwinKernelReleaseWithoutDeviceIdentifiers` (2330)
- `operatingSystemVersionSurfacesUseReportedStateInsteadOfGenericFallback` (2384)
- `legacySnapshotsDoNotInventOperatingSystemVersionDuringDecode` (2439)
- `snapshotsAvoidLocalDeviceNamesAndRawHardwareModels` (3680)

### 10. GPU
- `gpuInventoryDoesNotStoreRawRegistryIdentifiers` (2477)
- `gpuInventorySurfacesPublicThreadgroupCapabilities` (2494)
- `gpuPageUsesSharedDeviceCapabilityText` (2521)
- `legacyGPUDeviceMissingCapabilityFlagsDoesNotInventHighPerformanceDisplayState` (2625)
- `initializerGPUCapabilityOnlyDoesNotInventKindUnifiedMemoryOrDisplayRole` (2662)
- `gpuPageUnifiedMemorySummaryDoesNotInventUnsupportedStateForLegacyDevices` (2703)
- `missingGPUInventoryUsesReportedStateInsteadOfUndetectedHardwareAcrossSurfaces` (2734)
- `legacyGPUInventoryWithoutReportedDeviceFieldsDoesNotInventDeviceCountsAcrossSurfaces` (2798)
- `gpuDisplayPageFiltersLegacyInventoryRowsWithoutReportedFields` (2832)
- `statusPageSurfacesGPUInventorySignal` (6921)

### 11. 显示器
- `settingsDataSourceRowsUseSnapshotReportedStateInsteadOfHardcodedAvailability` (2868)
- `settingsDataSourceRowsSurfaceLoadAverageReportedState` (2983)
- `displayInventoryDoesNotStoreRawDisplayIdentifiers` (3006)
- `displaySamplerFallsBackToNSScreenWhenCoreGraphicsListIsEmpty` (3025)
- `displaySamplerUsesNSScreenRefreshRateWhenCoreGraphicsOmitsIt` (3037)
- `displayPageShowsSampledModeSizeAndRotation` (3052)
- `displayPageUsesSharedDisplayStateText` (3069)
- `legacyDisplayMissingTopologyAndRotationDoesNotInventExternalExtendedState` (3140)
- `initializerDisplayCapabilityOnlyDoesNotInventTopologyOrRotation` (3178)
- `missingDisplayMetricsUseReportedStateInsteadOfZeroOrAdaptiveText` (3224)
- `legacyDisplayInventoryWithoutReportedFieldsDoesNotInventDisplayCountsAcrossSurfaces` (3373)
- `displayPageSurfacesPublicPhysicalScreenSize` (3408)
- `displayPageSurfacesPublicBackingScaleFactor` (3437)
- `displayPageSurfacesPublicColorSpaceModelWithoutProfileNames` (3468)

### 12. 电池 / 电源
- `batterySamplerUsesPublicPowerSourceHealthKeys` (3503)
- `powerPageUsesSharedBatteryDetailDisplayText` (3526)
- `powerPageSummarySurfacesVoltageAndAmperageReadings` (3593)
- `batterySamplerChoosesInternalBatteryBeforeOtherPowerSources` (3615)
- `batterySamplerUsesProvidingPowerSourceWhenBatteryDetailsAreUnavailable` (3633)
- `batterySamplerUsesSystemTimeRemainingEstimateAsDischargeFallback` (3647)
- `batterySamplerDoesNotInferChargingStateFromACPowerWhenChargingFlagIsMissing` (3662)
- `powerSourceTextUsesReportedPowerSourceBeforeChargingFlag` (4071)
- `powerStatusTextUsesPowerSourceWhenBatteryPercentIsUnavailable` (4104)
- `powerStatusProgressUsesReportedPowerSourceWhenBatteryPercentIsUnavailable` (4141)
- `powerStatusToneUsesReportedPowerSourceWhenBatteryPercentIsUnavailable` (4216)
- `missingPowerSourceUsesReportedStateInsteadOfNoBatteryAcrossSurfaces` (4322)
- `overviewPowerCardUsesCurrentPowerStatusText` (4372)
- `powerTrendValuesUseReportedPowerSourceWhenBatteryPercentIsUnavailable` (4385)
- `powerPageForegroundsCurrentPowerStatusWhenBatteryPercentIsUnavailable` (4407)
- `statusSignalsUseCurrentPowerStatusWhenBatteryPercentIsUnavailable` (4420)
- `compactPowerSurfacesUseCurrentPowerStatusText` (4434)
- `blankBatteryPowerSourceDoesNotBecomeReportedNoBatteryState` (7300)
- `powerToneDistinguishesChargingBatteryAndLowPowerStates` (7541)

### 13. 占位 / 缓存 / 刷新生命周期
- `placeholderDoesNotPretendToContainLiveMetrics` (3710)
- `widgetPlaceholderUsesSkeletonAndTimelineSamplesDirectly` (3731)
- `systemSamplerCachesStaticInventoryBetweenLiveRefreshes` (3753)
- `systemSamplerCachesStaticSystemInfoWithoutCachingActiveProcessorCount` (3783)
- `mainAppWarmsDeltaBasedSamplerBeforePublishingInitialSnapshot` (3810)
- `resumeAfterPauseWarmsSamplerBeforePublishingSnapshot` (3832)
- `widgetDoesNotShowShortWindowNetworkThroughput` (3846)
- `widgetTimelineUsesCompactSnapshotWithoutUnusedInventoryLists` (7333)
- `appRefreshAndWidgetTimelineAvoidUnnecessaryWakeups` (7523)
- `pauseResumeResetsNetworkBaselinesAndRejectsStaleRefreshResults` (7612)

### 14. Widget 形态与外观
- `mediumWidgetSurfacesDeclaredCoreSignals` (3862)
- `largeWidgetSurfacesLoadAverageSignal` (3894)
- `largeWidgetSurfacesOperatingSystemVersionWithReportedState` (3917)
- `largeWidgetUsesBreathableTwoColumnSections` (3943)
- `mediumWidgetUsesRelaxedFirstVersionSpacingAndDarkModeText` (3971)
- `mediumWidgetUsesAirierFirstVersionStatusStrip` (3998)
- `widgetsOwnTheirContentMarginsInsteadOfUsingSystemDoubleInsets` (4028)
- `widgetHeadersAvoidTruncatedTitleAndVisibleTimeCrowding` (4051)
- `widgetTimelineKindUsesPulseDockSharedConstant` (7598)
- `widgetCopyDoesNotClaimRealtimeRefresh` (6703)
- `widgetExtensionDeclaresAttributesForGeneratedBundleMetadata` (7644)

### 15. 暗色模式 / 外观
- `widgetsAndMainWindowUseDynamicLightAndDarkAppearance` (4544)
- `dashboardWidgetPreviewUsesDynamicLightAndDarkAppearance` (4589)
- `widgetMetricRingsAndTilesUseDynamicDarkModeColors` (4620)
- `widgetPlaceholderSkeletonUsesDynamicDarkModeColors` (4645)

### 16. 菜单栏 Popover 几何与显示流程
- `menuPopoverActionsAreInteractive` (4797)
- `menuPopoverSurfacesLoadAverageInsteadOfDuplicateSampleTile` (4819)
- `menuPopoverSurfacesUptimeAndKernelVersionSignals` (4837)
- `menuPopoverUsesStableFixedSizeBeforeShowing` (4861)
- `menuPopoverChoosesVisibleScreenEdgeAndScrollableContentBeforeShowing` (4893)
- `menuPopoverGeometryClampsStatusBarPlacementFromAnchorFrame` (4926，**真实几何单元测试**)
- `menuPopoverReservesChromeAndConstrainsActualWindowFrame` (4967)
- `menuPopoverUsesPreparedPlacementForInitialShowAndFitsClampedContent` (4995)
- `menuPopoverRefitsWindowAfterClampedContentHeightChanges` (5026)
- `menuPopoverGeometryHorizontallyClampsStatusBarAnchorBeforeShowing` (5048，**真实几何单元测试**)
- `menuPopoverTreatsStatusBarWindowAsTopAnchoredBeforeShowing` (5093)
- `menuPopoverTreatsStatusBarLevelOrHigherAnchorWindowsAsTopAnchored` (5111)
- `menuPopoverPinsRootViewHeightBeforeShowing` (5133)
- `menuPopoverRebuildsSizedHostingControllerBeforeEachShow` (5159)
- `menuPopoverUsesStableStatusItemLengthWhileCPUTitleRefreshes` (5183)
- `menuPopoverDoesNotActivateAppAfterShowingStatusPopover` (5205)
- `menuPopoverHidesWindowUntilFinalFrameIsConstrained` (5228)
- `menuPopoverHidesContentBeforeInitialShowFrameIsRendered` (5261)

### 17. 设置 / 持久化 / 阈值 / 历史
- `settingsPageControlsRefreshAndHistoryState` (6714)
- `settingsPersistenceUsesAppOnlyDefaultsWithPrivacyReason` (6739)
- `statusThresholdsAreConfigurableAndPersisted` (6781)
- `overviewStatusUsesCPUAndMemoryThresholds` (6824)
- `overviewTrendSurfacesLoadAverageHistory` (6839)
- `statusPageUsesConfiguredThresholdRules` (6882)
- `statusPageSurfacesLoadAverageSignal` (6900)
- `statusPageSurfacesStorageVolumeSignal` (6942)
- `menuBarCPUDisplayCanBeToggledAndPersisted` (6963)
- `historyPersistenceUsesSanitizedTrendSnapshots` (6991)
- `historyPersistencePreservesSampledActiveProcessorCountForLoadTrends` (7022)
- `legacyHistoryWithoutActiveProcessorCountDoesNotInventLoadTrendDenominator` (7038)
- `sparklinesDoNotInventTrendSamples` (7087)
- `historyPageCopyReflectsPersistedHistory` (7098)
- `historySampleCountLabelsOnlyCountReportedSamples` (7109)
- `historyPageSurfacesPersistedDiskTrend` (7132)
- `historyPageSurfacesPersistedLoadTrend` (7152)
- `historyPageSurfacesPersistedThermalTrend` (7174)
- `historyPageSurfacesPersistedUptimeTrend` (7197)

### 18. 热状态
- `userFacingTextAvoidsInternalOrPlaceholderLanguage` (5759)
- `thermalDisplayTextUsesReportedStateInsteadOfRawUnknownAcrossSurfaces` (5777)
- `thermalLimitDisplayTextUsesSharedSnapshotModel` (5834)
- `thermalGaugeSuppressesMissingThermalStateInsteadOfDrawingNominalProgress` (5874)

### 19. App Store 打包 / 脚本 / 元数据 / 身份
- `projectMetadataDoesNotExposeLegacyMonitorWidgetIdentity` (4494)
- `macOSAppIconIsDeclaredGeneratedAndPackaged` (4505)
- `appStoreMetadataAvoidsUnusedAppGroupConfiguration` (4675)
- `appStoreVersionMetadataUsesArchiveBuildSettings` (4694)
- `appStoreSigningCanReceiveDevelopmentTeamFromEnvironment` (4719)
- `packageScriptPassesArchiveMetadataToProjectGenerationAndBuild` (4737)
- `appStoreArchiveScriptSeparatesSignedArchiveAndExportFlow` (4756)
- `installScriptVerifiesWidgetRegistrationBeforeReturning` (5314)
- `packageScriptSeparatesReleaseBuildFromLocalAdhocSigning` (5326)
- `packageScriptUsesDeterministicDerivedDataPath` (5349)
- `appStoreScriptsValidateProductionBundleIdsAndPackageIconBeforeSigning` (7376)
- `appStoreReadinessChecklistTracksCompletedFixes` (7405)
- `publicOpenSourceRepositoryIncludesReadmeAndMITLicense` (7429)
- `appStoreIdentityUsesPulseDockAcrossBundlesScriptsAndSurfaces` (7442)
- `appStoreMetadataDeclaresLocalizationCategoryAndAvoidsDeadAssetCatalogSettings` (7502)
- `releaseScriptsRegisterAppBundlesWithoutInvalidLsregisterOptions` (7584)

### 20. AppKit / 主窗口 / About / 可访问性
- `mainWindowCanBeRestoredAfterCloseOrDockReopen` (4785)
- `appDelegateInstallsStandardMainMenuAndRestorableStateHooks` (7479)
- `appKitPolishCoversAboutStatusItemAndReadOnlyWidgetRefreshSetting` (7628)
- `aboutPanelUsesInfoPlistCopyrightAndLicenseMatchesOwner` (7652)
- `mainWindowPersistsUserFrameAcrossLaunches` (7665)
- `customDashboardVisualControlsExposeAccessibilitySemantics` (7692)

## 测试质量评估

### 优点

1. **回归门覆盖极广**：234 个测试覆盖了几乎所有"已报告 / 未报告"状态边界、遗留 JSON 解码、初始化器默认值、源码层防止私有 API 泄漏等。这种"防止历史 bug 复发"的护栏对一个即将上架 App Store 的应用非常有价值。
2. **行为单元测试部分质量高**：`percentageFormatterClampsAndRoundsValues`、`bytesFormatterUsesBinaryUnits`、`networkRateFormatterUsesBitsPerSecond`、`minutesFormatterUsesCompactDurations`、`displaySnapshotExposesExpectedStrings`、`powerToneDistinguishesChargingBatteryAndLowPowerStates` 等真实调用 API 并断言具体输出，是文件中的标杆。
3. **`MenuBarPopoverGeometry` 真实单元测试优秀**（4926、5048）：直接调用 `MenuBarPopoverGeometry.placement(...)` 并断言 `preferredEdge`、`availableHeight`、`size`、`anchorScreenMidX` 的精确数值，覆盖了状态栏锚点、常规锚点、窄屏边缘 clamp 等边界。这是纯函数、无副作用、无 IO 的理想单测对象。
4. **遗留 JSON 解码行为测试有价值**：33 处 `JSONDecoder().decode` 验证旧版本持久化数据在新模型上仍能正确解码且不"发明"字段（如 `legacyNetworkPathMissingSupportFlagsDoesNotInventUnsupportedCapabilities` 345、`legacyHistoryWithoutActiveProcessorCountDoesNotInventLoadTrendDenominator` 7038）。这对一个会持久化历史快照的应用是真实的兼容性保障。
5. **顺序断言有创造性**：`mainWindowPersistsUserFrameAcrossLaunches` (7665) 和 `menuPopoverHidesContentBeforeInitialShowFrameIsRendered` (5261) 通过 `range(of:)` 比较两个标记在源码中的先后位置，验证"setFrameAutosaveName 在 center() 之前"、"hide 在 show 之前、restore 在 display 之后"等执行顺序约束——比单纯存在性检查更接近行为。
6. **测试命名高度规范化**：几乎所有测试名都遵循 `<场景>Uses<期望>InsteadOf<反模式>` 或 `<场景>DoesNotInvent<错误状态>` 模式，能清晰表达意图。
7. **框架选型现代**：Swift Testing 的 `@Test` / `#expect` / `#require` 比 XCTest 更简洁，符合 2025 年 Swift 社区方向。

### 不足

1. **源码字符串扫描占比过高（~79%）**：2129 条 `.contains` 断言绝大多数是在验证"源码里是否包含某段精确字符串"。这类测试不是验证行为，而是验证实现文本。它们在重构（重命名、提取方法、调整格式化、SwiftFormat 自动格式化）时会大量误报失败，而真正的 bug 反而无法被检出。
2. **审计文档自校验形成自引用闭环**：367 条 `audit.contains("...")` 断言要求 `docs/data-capability-audit.md` 文件包含特定句子。由于文档和测试是同一作者维护，这相当于"测试我写的文档里有我写的句子"，既不能验证文档真实性，也不能验证代码行为，只是把文档变成了一份与测试强耦合的、不能改写措辞的契约。任何文档润色都会破坏测试。
3. **`formattersGuardNonFiniteDoubleInputsBeforeIntegerConversion` (7220) 是错置的测试**：`MetricFormatting.percentage/.bitRate/.duration/.load` 都有 `guard value.isFinite else { return "未报告" }`，但该测试只检查源码里有没有这行 guard，**从没有调用 `MetricFormatting.percentage(.nan)` 或 `.infinity` 来验证实际返回 "未报告"**。这是把行为测试降级为源码扫描的典型反模式——guard 可能被错误删除并替换为另一段同样包含 "isFinite" 字样的代码，测试仍会通过。
4. **格式化器边界覆盖缺失**：
   - `bytes(0)`、`bytes(UInt64.max)`、`bytes(1023)`、`bytes(1024)`（单位跳变边界）、TB 级别未测。
   - `percentage(0.5)` 中间值、`percentage(.nan)`、`percentage(.infinity)`、`percentage(-.infinity)` 未测。
   - `bitRate(bitsPerSecond: 999_999_999)` 与 `1_000_000_000`（Mbps↔Gbps 阈值边界）未测；`bitRate(0)` 未测。
   - `compactBytes`、`byteRate`、`load`、`duration` 四个格式化器**完全没有直接单元测试**（`duration` 仅通过 `uptimeText` 间接覆盖）。
   - `minutes(0)`、`minutes(1440)`（刚好 1 天边界）、`minutes(1439)`、负数未测。
5. **环境耦合**：所有源码扫描测试依赖 `FileManager.default.currentDirectoryPath`，必须在仓库根目录运行。`swift test` 默认行为下通常成立，但通过 Xcode UI 或从子目录运行会全部以 "file not found" 失败，错误信息不直观。
6. **`samplerDoesNotExposeCrossProcessDetailsInAppStoreMode` (1640) 是脆弱的环境依赖测试**：直接调用 `SystemSampler().sample()` 断言 `processCount == 0`。在不同沙盒/签名/CI 环境下行为可能漂移，且测试名暗示验证"App Store 模式"，但实际并没有断言模式本身。
7. **大量重复样板**：几乎每个源码扫描测试都重复 4–8 行的 `let root = URL(...); let x = try String(contentsOf: root.appendingPathComponent("..."))`。应抽取为 helper（如 `func source(_ path: String) throws -> String`）或一次性 fixture，可减少约 1500 行。
8. **`!dashboardView.contains("旧代码片段")` 类断言模糊**：很多反存在性断言检查的是"旧的反模式代码不在源码里"，但旧代码片段的具体写法（变量名、括号位置、空格）一旦在另一处巧合出现会误判，且无法防止以新形式重新引入同类 bug。
9. **超长文件难以维护**：7702 行单文件、234 个测试混杂 20 个功能域，定位与增删都很困难。应按域拆分为 `MetricFormattingTests`、`NetworkPathTests`、`NetworkInterfaceTests`、`StorageTests`、`MemoryTests`、`CPUTests`、`GPUTests`、`DisplayTests`、`BatteryTests`、`MenuPopoverTests`、`WidgetTests`、`SettingsPersistenceTests`、`HistoryTests`、`AppStorePackagingTests`、`AppKitChromeTests` 等。

### 脆弱性分析

| 脆弱源 | 影响 | 严重度 |
|---|---|---|
| 精确字符串包含（含中文标点、`\n`、转义） | 任何格式化、重命名、SwiftFormat 运行都可能破坏数十个测试 | 高 |
| `audit.contains(...)` 文档措辞锁定 | 文档润色即破坏测试 | 高 |
| `FileManager.default.currentDirectoryPath` 依赖 | 工作目录变更即全部源码扫描测试失败 | 中 |
| `!source.contains("旧反模式")` 反存在性 | 巧合字符串误判，且无法防新形式回归 | 中 |
| `SystemSampler().sample()` 真实采样 | 环境差异导致结果漂移 | 中 |
| 区间顺序断言（`range(of:)` 比较） | 依赖两个标记同时存在且相对位置不变 | 低-中 |
| 真实几何计算（`MenuBarPopoverGeometry`） | 纯函数，**不脆弱** | 低 |

## 缺失测试识别

按重要性排序，下列关键逻辑**没有任何真正的行为级测试**（仅有源码扫描）：

1. **并发与竞态**：`MetricsStore` 使用 `@MainActor` + `Task.detached` + `refreshGeneration` 守卫（`MetricsStore.swift:298-315`）防止陈旧刷新结果覆盖新结果。`pauseResumeResetsNetworkBaselinesAndRejectsStaleRefreshResults` (7612) 只源码扫描这些标识符，**从不实际触发两次并发刷新并验证旧结果被丢弃**。这是测试套件最大的盲区——并发 bug 无法被检出。
2. **格式化器的 NaN/Infinity 实际行为**：guard 存在性被扫描，但从未用真实 NaN/Infinity 输入验证返回 "未报告"。
3. **JSON 编码 round-trip**：`MetricSnapshot` 的 `Codable` 只测了解码（33 处），从未测编码后再解码是否等价。`historyPersistenceUsesSanitizedTrendSnapshots` 只扫描 `JSONEncoder().encode` 字样，不验证序列化结果。
4. **`compactBytes` / `byteRate` / `load` / `duration` 格式化器**：完全无直接单元测试。
5. **`MetricFormatting.bytes` 单位边界**：1023→1024、1024^2、1024^3、1024^4 跳变点和 TB 分支未测。
6. **内存释放 / mach 端口管理**：`samplerReleasesMachHostPortsAndDoesNotReportFailedMemoryStatsAsZeroUsage` (7320) 只扫描 `defer { mach_port_deallocate(...) }` 字样，不验证端口实际被释放（可用 `mach_port_mod_refs` 检测，或在测试中注入失败路径验证返回 `false` 的 isReported）。
7. **Widget timeline 实际刷新逻辑**：`appRefreshAndWidgetTimelineAvoidUnnecessaryWakeups` (7523) 只扫描 `WidgetCenter.shared.reloadTimelines(ofKind:)` 字样，从不实际触发 timeline 刷新并验证调用次数/节流。
8. **真实 UI 渲染 / 可访问性**：`customDashboardVisualControlsExposeAccessibilitySemantics` (7692) 只扫描 `.accessibilityLabel(...)` 字样，无快照测试、无 ` accessibilityAudit()` 实际执行。对一个上架 App Store 的应用，至少应有少量 View body 渲染与可访问性审计。
9. **阈值边界行为**：`statusThresholdsAreConfigurableAndPersisted` (6781) 扫描 Slider 字样，但从不实际设置阈值并验证 `usageStatusLevel` 在 usage == threshold 时的状态分级（normal/warning/critical 边界）。
10. **本地化**：所有中文字符串（"未报告"、"在线"、"离线"等）被源码扫描当作硬编码契约，但 `appStoreMetadataDeclaresLocalizationCategoryAndAvoidsDeadAssetCatalogSettings` (7502) 声明了 `zh-Hans` 本地化。没有测试验证 `String(localized:)` / `.strings` 文件是否与硬编码中文一致，存在"改了本地化但 UI 仍是硬编码"或反之的风险。
11. **暂停/恢复的状态机**：`pauseResumeResetsNetworkBaselinesAndRejectsStaleRefreshResults` (7612) 全部是源码扫描，从不实际调用 `togglePause()` 两次并验证 `isPaused` 状态翻转、定时器失效、网络基线重置。
12. **`MetricSnapshot.placeholder` 的显示文本一致性**：`placeholderDoesNotPretendToContainLiveMetrics` (3710) 只验证数值为 0/空，不验证所有 `*Text` 计算属性都返回 "未报告"（只有部分测试零散验证个别属性）。

## 问题汇总

### Bug 级

| # | 行号 | 问题 | 建议 |
|---|------|------|------|
| 1 | 7220-7230 | `formattersGuardNonFiniteDoubleInputsBeforeIntegerConversion` 只源码扫描 guard，从未调用 `MetricFormatting.percentage(.nan)/.infinity`、`bitRate(bitsPerSecond: .nan)`、`duration(.nan)`、`load(.nan)` 验证实际返回 "未报告"。guard 可能被替换为含 "isFinite" 字样的错误实现而测试仍通过 | 改为真实调用并断言 `== "未报告"`，源码扫描仅作辅助 |
| 2 | 1640-1645 | `samplerDoesNotExposeCrossProcessDetailsInAppStoreMode` 断言 `SystemSampler().sample().processCount == 0`，但测试名承诺验证"App Store 模式"，实际未断言任何模式开关；在非沙盒环境下 `processCount` 可能非 0 导致误失败 | 注释说明环境前提，或注入 sampler 配置以确定性控制 |
| 3 | 13-17 | `bytesFormatterUsesBinaryUnits` 测试名声称"BinaryUnits"，但 `MetricFormatting.bytes` 输出的是 "KB/MB/GB/TB"（十进制命名）却用 1024 除法，名实不符且未覆盖 TB 分支与 1024 边界 | 补充 `bytes(0)=="0 B"`、`bytes(1023)`、`bytes(1024)=="1.0 KB"`、`bytes(UInt64.max)` 边界，并修正测试名表述 |
| 4 | 19-24 | `networkRateFormatterUsesBitsPerSecond` 未测试 Mbps↔Gbps 阈值边界（999_999_999 vs 1_000_000_000）和 `bitRate(bitsPerSecond: 0)`、`bitRate(bitsPerSecond: .nan)` | 补充阈值边界与异常输入测试 |
| 5 | 7376-7403 | `appStoreScriptsValidateProductionBundleIdsAndPackageIconBeforeSigning` 等打包脚本测试在测试 bundle 中执行 shell 脚本的字符串扫描，但 `scripts/archive-app-store.sh` 的实际执行正确性从未被验证（如 `validate_bundle_identifier` 函数行为） | 增加少量 shell 单元测试或用 `bash -n` 语法检查 + 关键函数行为测试 |

### 质量级

| # | 行号 | 问题 | 建议 |
|---|------|------|------|
| 1 | 全文 | 源码字符串扫描占 ~79%（2129/2623 断言），对重构极度脆弱 | 将行为可测的部分（格式化、几何、Codable、阈值分级、状态机）改为真实单元测试；保留少量关键反回归扫描 |
| 2 | 全文 | 367 条 `audit.contains(...)` 把 `docs/data-capability-audit.md` 锁成不可改写的契约，形成测试↔文档自引用闭环 | 删除大部分文档措辞断言，仅在文档自身有自动化校验需求时保留少量 |
| 3 | 全文 | 7702 行单文件、234 测试混杂 20 个功能域 | 按域拆分为约 15 个测试文件 |
| 4 | 全文 | 重复样板 `let root = URL(...); let x = try String(contentsOf:...)` 约出现 180 次 | 抽取 `func source(_ path: String) throws -> String` helper |
| 5 | 全文 | 依赖 `FileManager.default.currentDirectoryPath`，工作目录变更即全部失败 | 改用 `Bundle(for:)` 资源定位或 `#filePath` 相对路径 |
| 6 | 614-618 | `minutesFormatterUsesCompactDurations` 未覆盖 `minutes(0)`、`minutes(1440)`（刚好 1 天）、负数 | 补充边界 |
| 7 | 620-648 | `displaySnapshotExposesExpectedStrings` 只覆盖一个组合快照，未覆盖各字段单独的"未报告"路径 | 拆分为按字段的参数化测试 |
| 8 | 4995-5024, 5261-5312 | `range(of:)` 区间提取 + 顺序断言较复杂，依赖源码中两个标记同时存在且顺序不变；若任一标记被重构删除，`?? .startIndex/.endIndex` 回退会静默通过 | 用 `try #require(...)` 代替 `??`，让缺失标记直接报错 |
| 9 | 7541-7582 | `powerToneDistinguishesChargingBatteryAndLowPowerStates` 只覆盖 charging/battery-high/battery-low 三态，未覆盖 low-power 模式、充电中低电量、AC 但无电池等组合 | 扩展为参数化测试矩阵 |
| 10 | 全文 | 无并发测试：`refreshGeneration` 守卫、`Task.detached` 取消、`timer?.invalidate()` 等并发安全逻辑全部只源码扫描 | 用 `Task` + `async` 测试实际并发场景 |
| 11 | 全文 | 无 UI 渲染/可访问性行为测试，仅扫描 `.accessibilityLabel` 字样 | 至少为关键自绘控件添加 `ViewRenderer` 快照或 `accessibilityAudit()` |
| 12 | 全文 | `compactBytes`/`byteRate`/`load`/`duration` 四个格式化器零直接测试 | 补充单元测试 |
| 13 | 全文 | 无 `MetricSnapshot` 编码 round-trip 测试 | 增加 `encode → decode → 等价` 测试 |
| 14 | 全文 | 本地化字符串被当硬编码契约扫描，与 `zh-Hans` 本地化声明存在潜在不一致风险 | 增加本地化键与硬编码 fallback 一致性测试 |
| 15 | 7405-7427 | `appStoreReadinessChecklistTracksCompletedFixes` 校验一个 markdown checklist 的 `[x]` 状态，本质是把待办清单当测试契约，清单更新即破坏测试 | 移除或改为校验已完成项数 ≥ 阈值 |

## 亮点

- **`menuPopoverGeometryClampsStatusBarPlacementFromAnchorFrame` (4926) 与 `menuPopoverGeometryHorizontallyClampsStatusBarAnchorBeforeShowing` (5048)**：对 `MenuBarPopoverGeometry.placement` 纯函数进行真实数值断言（`preferredEdge == .minY`、`availableHeight == 336`、`anchorScreenMidX == 1250`、`size.width == 276`），覆盖状态栏/常规锚点、窄屏、边缘 clamp 等多边界，是整套测试中质量最高的部分，应作为其余测试的改造模板。
- **遗留 JSON 解码测试族**（如 345、1016、2130、7038、7276 等 33 处）：真实 `JSONDecoder().decode` 旧版本数据并断言字段不"发明"，对持久化历史快照的应用是实打实的兼容性保障。
- **`mainWindowPersistsUserFrameAcrossLaunches` (7665) 与 `menuPopoverHidesContentBeforeInitialShowFrameIsRendered` (5261)**：用 `range(of:)` 顺序比较验证执行顺序约束，比单纯存在性检查更接近行为。
- **`powerToneDistinguishesChargingBatteryAndLowPowerStates` (7541)**：构造三态快照断言 `powerStatusTone` 真实分级，是行为测试的好例子（虽组合覆盖不足）。
- **`placeholderDoesNotPretendToContainLiveMetrics` (3710)**：直接断言 `MetricSnapshot.placeholder` 的所有数值字段为 0/空，简单清晰。
- **测试命名规范**：`<场景>Uses<期望>InsteadOf<反模式>` / `<场景>DoesNotInvent<错误>` 模式一致，可读性高。
- **回归门意图明确**：大量 `!source.contains("旧反模式")` 断言明确记录了"曾出现过此 bug，禁止复发"，对一个即将上架的应用是合理的防御性测试。

## 模块整体评价

**评分：6 / 10**

这是一份**意图优秀、执行偏移**的测试套件。作者显然对应用的功能边界、App Store 审核风险点、历史 bug 有深刻理解——234 个测试覆盖了网络/存储/内存/CPU/GPU/显示/电池/菜单栏/Widget/打包脚本/元数据等几乎所有功能域，且每个测试名都精确表达了"防止什么回归"。作为"回归门"它覆盖面极广。

但**约 79% 的断言是源码字符串扫描**，把测试从"验证行为"降级为"验证实现文本"。这带来三个核心问题：(1) 重构脆弱性——任何 SwiftFormat 运行、方法提取、变量重命名都可能触发数十个误报；(2) 行为盲区——guard 存在性被扫描但 NaN 实际输入从未被调用、并发守卫被扫描但竞态从未被触发、可访问性字面量被扫描但 `accessibilityAudit()` 从未执行；(3) 文档自引用——367 条 `audit.contains` 把 `data-capability-audit.md` 锁成不可改写的契约，测试与文档由同一人维护时形成自我闭环。

**改进优先级建议**：
1. 把 `MetricFormatting` 全部格式化器（含 NaN/Infinity/边界）改为真实单元测试（1-2 天工作量，收益最大）。
2. 为 `MetricsStore` 的并发/暂停/恢复状态机增加真实行为测试（关键风险点）。
3. 删除或大幅精简 `audit.contains` 断言，解除文档锁定。
4. 按功能域拆分文件并抽取源码加载 helper。
5. 保留 `MenuBarPopoverGeometry` 风格的真实单元测试作为新测试的准入标准，源码扫描仅作为反回归辅助。

如果完成 1-3 项，评分可提升至 8/10。
