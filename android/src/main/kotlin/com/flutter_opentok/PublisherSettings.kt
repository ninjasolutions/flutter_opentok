package com.flutter_opentok

import kotlinx.serialization.Serializable

@Serializable
data class PublisherSettings(
        var name: String?,
        var audioTrack: Boolean?,
        var videoTrack: Boolean?,
        var audioBitrate: Int?,
        var cameraResolution: String?,
        var cameraFrameRate: String?)
