package com.gcinterceptor.msgpush;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import com.gcinterceptor.spring.SpringGcInterceptor;
import com.gcinterceptor.spring.SpringGcInterceptorConfiguration;

@SpringBootApplication
@Import(SpringGcInterceptorConfiguration.class)
public class MsgPush {
	private static final boolean USE_GCI = Boolean.parseBoolean(System.getenv("USE_GCI"));
	private static int MSG_SIZE;
	private static int WINDOW_SIZE;
	private static int COMPUTING_TIME_MS = 15;
	private static int SLEEP_TIME_MS = 5;
	private static byte[][] buffer;
	private static int msgCount;

	static {
		WINDOW_SIZE = Integer.parseInt(System.getenv("WINDOW_SIZE"));
		MSG_SIZE = Integer.parseInt(System.getenv("MSG_SIZE"));
		if (WINDOW_SIZE>0) {
			buffer = new byte[WINDOW_SIZE][MSG_SIZE];
		}
		try {
			SLEEP_TIME_MS = Integer.parseInt(System.getenv("SLEEP_TIME_MS"));
		} catch (NumberFormatException nfe){}		

	}

	public static void main(String[] args) {
		SpringApplication.run(MsgPush.class, args);
	}

	@Bean
	public WebMvcConfigurer adapter() {
		return new WebMvcConfigurer() {
			@Autowired
			SpringGcInterceptor gci;

			@Override
			public void addInterceptors(InterceptorRegistry registry) {
				if (USE_GCI) {
					registry.addInterceptor(gci);
				}
			}
		};
	}

	@RestController
	public static class HelloController {
		@RequestMapping("/*")
		public void index() throws InterruptedException {
			byte[] byteArray = new byte[MSG_SIZE];

			if (WINDOW_SIZE > 0) {
				buffer[msgCount++ % WINDOW_SIZE] = byteArray;
			}

			long max = 5000;
			long count = 0;
			for (long i = 3; i <= max; i++) {
				boolean isPrime = true;
				for (long j = 2; j <= i / 2 && isPrime; j++) {
					isPrime = i % j > 0;
				}
				if (isPrime) {
					count++;
				}
			}


			if (SLEEP_TIME_MS > 0) {
				Thread.sleep(SLEEP_TIME_MS);
			}
		}
	}
}
