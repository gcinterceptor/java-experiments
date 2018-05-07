package com.gcinterceptor.server;

import java.io.BufferedWriter;
import java.io.InputStream;
import java.net.InetSocketAddress;
import java.nio.file.Paths;
import java.nio.file.Files;
import java.util.concurrent.TimeUnit;

import com.gcinterceptor.core.GarbageCollectorControlInterceptor;
import com.gcinterceptor.core.ShedResponse;

import com.sun.net.httpserver.Headers;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;

public class Server {
	private static final String GCI_HEADERS_NAME = "GCI";
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
		BufferedWriter stWriter = Files.newBufferedWriter(Paths.get("st.csv"));
		Runtime.getRuntime().addShutdownHook(new Thread() { // Ensure that the file will be closed at the end.
			public void run() {
				try {
					stWriter.close();
				} catch (Exception e) {
					e.printStackTrace();
				}
			}
		});

		GarbageCollectorControlInterceptor gci = new GarbageCollectorControlInterceptor();
		HttpServer server = HttpServer.create(new InetSocketAddress(PORT), 0);
		server.createContext("/", (HttpExchange t) -> {
			long startTime = System.nanoTime();
			InputStream is = t.getRequestBody();
			while (is.read() != -1) {}
			is.close();
			int statusCode = 200;
			ShedResponse shedResponse = gci.before(t.getRequestHeaders().getFirst(GCI_HEADERS_NAME));
			if (shedResponse.shouldShed) {
				statusCode = 503;
			} else {
				handler();
			}
			gci.after(shedResponse);
			t.sendResponseHeaders(statusCode, 0);
			t.close();
			long finishTime = System.nanoTime();
			stWriter.write(Long.toString(TimeUnit.NANOSECONDS.toMillis(finishTime - startTime)));
			stWriter.newLine();

		});		
		server.setExecutor(null); 
		server.start();
	}

	static void handler() {
		byte[] byteArray = new byte[MSG_SIZE];
		for (int i = 0; i < MSG_SIZE; i++) {
			byteArray[i] = (byte) i;
		}
		if (WINDOW_SIZE > 0) {
			buffer[msgCount++ % WINDOW_SIZE] = byteArray;
		}
		try {
			Thread.sleep(SLEEP_TIME_MS);
		} catch (InterruptedException ie) {
			// This should kill the server.
			throw new RuntimeException(ie);
		}
		long t = COMPUTING_TIME_MS + System.currentTimeMillis();
		while (t > System.currentTimeMillis()) {}
	}
}
