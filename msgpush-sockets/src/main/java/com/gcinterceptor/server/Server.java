package com.gcinterceptor.server;

import com.gcinterceptor.core.GarbageCollectorControlInterceptor;
import com.gcinterceptor.core.ShedResponse;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.ServerSocket;
import java.net.Socket;

public class Server {
	private static final String GCI_HEADERS_NAME = "Gci";
	private static final boolean USE_GCI = Boolean.parseBoolean(System.getenv("USE_GCI"));
	private static int MSG_SIZE;
	private static int WINDOW_SIZE;
	private static int COMPUTING_TIME_MS = 15;
	private static int SLEEP_TIME_MS = 5;
	private static int PORT;
	private static byte[][] buffer;
	private static int msgCount;

	static {
		PORT = Integer.parseInt(System.getenv("PORT"));
		WINDOW_SIZE = Integer.parseInt(System.getenv("WINDOW_SIZE"));
		MSG_SIZE = Integer.parseInt(System.getenv("MSG_SIZE"));
		if (WINDOW_SIZE>0) {
			buffer = new byte[WINDOW_SIZE][MSG_SIZE];
		}
		// Optional variables.
		try {
			COMPUTING_TIME_MS = Integer.parseInt(System.getenv("COMPUTING_TIME_MS"));
		} catch (NumberFormatException nfe) {}
		try {
			SLEEP_TIME_MS = Integer.parseInt(System.getenv("SLEEP_TIME_MS"));
		} catch (NumberFormatException nfe){}	
	}

	public static void main(String[] args) throws Exception {
		GarbageCollectorControlInterceptor gci = new GarbageCollectorControlInterceptor();
		ServerSocket server = new ServerSocket(PORT);
		server.setReuseAddress(true);
		server.setSoTimeout(1000);
		while (true) {
			try (Socket socket = server.accept()) {
				BufferedReader in = new BufferedReader(new InputStreamReader(socket.getInputStream()));	
				String line = "";
				String gciHeader = null;
				while ((line = in.readLine()) != null && line.length() > 0) {
					if (line.contains(GCI_HEADERS_NAME)) {
						gciHeader = line;
						break;
					}
				}
				int statusCode = 200;
				String statusText = "OK";
				if (USE_GCI) {
					// Consume the input stream and search for GCI header.
					ShedResponse shedResponse = gci.before(gciHeader);
					if (shedResponse.shouldShed) {
						statusCode = 503;
						statusText = "Service Unavailable";
					} else {
						handler();
					}		
					gci.after(shedResponse);
				} else {
					handler();
				}
				String response = String.format("HTTP/1.1 %d %s\r\n\r\n", statusCode, statusText);
				socket.getOutputStream().write(response.getBytes("UTF-8"));
			}
		}
	}

	static void handler() throws Exception {
		byte[] byteArray = new byte[MSG_SIZE];
		for (int i = 0; i < MSG_SIZE; i++) {
			byteArray[i] = (byte) i;
		}
		if (WINDOW_SIZE > 0) {
			buffer[msgCount++ % WINDOW_SIZE] = byteArray;
		}
		if (SLEEP_TIME_MS > 0) {
			try {
				Thread.sleep(SLEEP_TIME_MS);
			} catch (InterruptedException ie) {
				// This should kill the server.
				throw new RuntimeException(ie);
			}
		}
		if (COMPUTING_TIME_MS > 0) {
			long t = COMPUTING_TIME_MS + System.currentTimeMillis();
			while (t > System.currentTimeMillis()) {}
		}
	}
}
