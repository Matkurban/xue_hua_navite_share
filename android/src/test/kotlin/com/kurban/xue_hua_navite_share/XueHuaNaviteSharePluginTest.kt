package com.kurban.xue_hua_navite_share

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.ArgumentCaptor
import org.mockito.Mockito
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

internal class XueHuaNaviteSharePluginTest {
    @Test
    fun onMethodCall_getCapabilities_returnsAndroidCapabilities() {
        val plugin = XueHuaNaviteSharePlugin()

        val call = MethodCall("getCapabilities", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        val captor = ArgumentCaptor.forClass(Any::class.java)
        Mockito.verify(mockResult).success(captor.capture())
        val map = captor.value as Map<*, *>
        assertEquals("android", map["platform"])
        assertEquals(true, map["supportsSystemShareSheet"])
        assertEquals(true, map["supportsFileSharing"])
    }

    @Test
    fun onMethodCall_canShare_validatesItemsList() {
        val plugin = XueHuaNaviteSharePlugin()

        val args = mapOf(
            "items" to listOf(
                mapOf("type" to "text", "text" to "Hello Android Share")
            )
        )
        val call = MethodCall("canShare", args)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).success(true)
    }
}
